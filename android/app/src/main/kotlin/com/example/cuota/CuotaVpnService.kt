package com.example.cuota

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import hev.htproxy.TProxyService
import java.io.File
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Local VPN: apps -> TUN -> hev-socks5-tunnel -> [SocksBridge] -> cntlm -> Squid.
 * The app itself stays out of the VPN, otherwise cntlm would loop into it.
 */
class CuotaVpnService : VpnService() {
    private var cntlm: Process? = null
    private var bridge: SocksBridge? = null
    private var tun: ParcelFileDescriptor? = null
    private var logcat: Process? = null
    private val recentLines = ArrayDeque<String>()
    private var lastQuotaEvent = 0L

    @Volatile
    private var stopping = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            thread {
                shutDown()
                pendingStop?.invoke()
                pendingStop = null
            }
            return START_NOT_STICKY
        }
        val request = pendingRequest
        if (request == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        pendingRequest = null
        startForegroundCompat()
        thread {
            try {
                bringUp(request)
                runningProfileId = request.profileId
                request.onResult(null)
            } catch (e: IOException) {
                shutDown()
                request.onResult(e.message ?: "No se pudo iniciar el proxy")
            }
        }
        return START_NOT_STICKY
    }

    private fun bringUp(request: StartRequest) {
        stopping = false
        killLeftoverCntlm()
        ensurePortFree(request.port)
        startCntlm(request)

        val socks = SocksBridge(request.port, ::reportQuotaBlocked, ::log)
        bridge = socks
        socks.start()

        val fd = establishTun()
        tun = fd
        val config = File(privateDir(), "tunnel.yml")
        config.writeText(tunnelConfig(socks.port))
        if (!TProxyService.TProxyStartService(config.path, fd.fd)) {
            throw IOException("No se pudo iniciar el túnel")
        }
        log("Túnel VPN activo")
    }

    private fun ensurePortFree(port: Int) {
        try {
            ServerSocket(port, 1, InetAddress.getByName("127.0.0.1")).close()
        } catch (_: IOException) {
            throw IOException(
                "El puerto $port ya está en uso. Cierre el programa que lo ocupa " +
                    "o cambie el puerto en \"Servidor y red\"",
            )
        }
    }

    private fun startCntlm(request: StartRequest) {
        val config = File(privateDir(), "cntlm.conf")
        config.writeText(request.config)
        try {
            val process = ProcessBuilder(cntlmPath(this), "-c", config.path, "-f")
                .redirectErrorStream(true)
                .start()
            cntlm = process
            startLogcat()
            thread(isDaemon = true) {
                // Reading the output also keeps cntlm from blocking on a full pipe.
                runCatching { process.inputStream.bufferedReader().forEachLine(::logCntlmLine) }
                val code = process.waitFor()
                log("cntlm terminó con código $code")
                if (!stopping) failFromBackground("El proxy se detuvo inesperadamente, inícielo de nuevo")
            }
            waitUntilListening(request.port, process)
        } finally {
            config.delete()
        }
    }

    private fun waitUntilListening(port: Int, process: Process) {
        val deadline = System.currentTimeMillis() + START_TIMEOUT_MS
        while (System.currentTimeMillis() < deadline) {
            if (!process.isAliveCompat()) break
            try {
                Socket().use {
                    it.connect(InetSocketAddress("127.0.0.1", port), 200)
                }
                return
            } catch (_: IOException) {
                Thread.sleep(100)
            }
        }
        throw IOException("El proxy no pudo iniciarse, revise los datos en \"Servidor y red\"")
    }

    private fun establishTun(): ParcelFileDescriptor {
        val builder = Builder()
            .setSession("Cuota")
            .setMtu(TUN_MTU)
            .addAddress(TUN_IPV4, 15)
            .addAddress(TUN_IPV6, 126)
            .addDnsServer(MAPPED_DNS)
            // IPv6 is captured so it cannot leave outside the proxy.
            .addRoute("::", 0)
            .addDisallowedApplication(packageName)
        ROUTES_WITHOUT_PRIVATE_NETWORKS.forEach { (address, prefix) ->
            builder.addRoute(address, prefix)
        }
        return builder.establish()
            ?: throw IOException("Android no autorizó la VPN, inténtelo de nuevo")
    }

    private fun tunnelConfig(socksPort: Int) = """
        tunnel:
          mtu: $TUN_MTU
          ipv4: $TUN_IPV4
          ipv6: '$TUN_IPV6'
        socks5:
          port: $socksPort
          address: 127.0.0.1
          udp: 'tcp'
        mapdns:
          address: $MAPPED_DNS
          port: 53
          network: 100.64.0.0
          netmask: 255.192.0.0
          cache-size: 10000
    """.trimIndent()

    /** Connections fail right after each other, once a minute is enough to tell. */
    private fun reportQuotaBlocked() {
        val now = System.currentTimeMillis()
        if (now - lastQuotaEvent < QUOTA_EVENT_INTERVAL_MS) return
        lastQuotaEvent = now
        events?.invoke(mapOf("type" to "quota"))
    }

    private fun failFromBackground(message: String) {
        shutDown()
        events?.invoke(mapOf("type" to "exit", "message" to message))
    }

    @Synchronized
    private fun shutDown() {
        stopping = true
        runningProfileId = null
        runCatching { TProxyService.TProxyStopService() }
        runCatching { tun?.close() }
        tun = null
        bridge?.close()
        bridge = null
        stopCntlm()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /** Bionic may send what cntlm writes to syslog to logcat instead of stderr. */
    private fun startLogcat() {
        val process = runCatching {
            ProcessBuilder("logcat", "-v", "raw", "-T", "1", "-s", "cntlm:V")
                .redirectErrorStream(true)
                .start()
        }.getOrNull() ?: return
        logcat = process
        thread(isDaemon = true) {
            runCatching {
                process.inputStream.bufferedReader().forEachLine { line ->
                    if (!line.startsWith("---")) logCntlmLine(line)
                }
            }
        }
    }

    /** The same line can arrive through both channels, it is only shown once. */
    @Synchronized
    private fun logCntlmLine(line: String) {
        val text = line.replace(CNTLM_LINE_PREFIX, "").trim()
        if (text.isEmpty() || text in recentLines) return
        recentLines.addLast(text)
        if (recentLines.size > RECENT_LINES) recentLines.removeFirst()
        log(text)
    }

    /** With connections open cntlm ignores the first signal, so it may need force. */
    private fun stopCntlm() {
        val process = cntlm ?: return
        cntlm = null
        logcat?.destroy()
        logcat = null
        recentLines.clear()
        process.destroy()
        if (!process.waitFor(STOP_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
            process.destroyForcibly()
            process.waitFor(STOP_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        }
    }

    /** A cntlm that outlived this process would keep the port taken. */
    private fun killLeftoverCntlm() {
        val binary = cntlmPath(this)
        File("/proc").listFiles()?.forEach { entry ->
            val pid = entry.name.toIntOrNull() ?: return@forEach
            val isCntlm = runCatching {
                File(entry, "cmdline").readText().startsWith(binary)
            }.getOrDefault(false)
            if (isCntlm) {
                android.os.Process.killProcess(pid)
                Thread.sleep(LEFTOVER_KILL_DELAY_MS)
            }
        }
    }

    /** Another VPN took over, or the user disabled this one in the settings. */
    override fun onRevoke() {
        thread { failFromBackground("Android desactivó la VPN de esta aplicación") }
    }

    override fun onDestroy() {
        if (!stopping) shutDown()
        super.onDestroy()
    }

    private fun privateDir() = File(noBackupFilesDir, "vpn").apply { mkdirs() }

    private fun startForegroundCompat() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Proxy", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        startForeground(
            NOTIFICATION_ID,
            builder
                .setContentTitle("Cuota")
                .setContentText("El tráfico pasa por el proxy de la universidad")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(open)
                .setOngoing(true)
                .build(),
        )
    }

    class StartRequest(
        val config: String,
        val port: Int,
        val profileId: String,
        val onResult: (error: String?) -> Unit,
    )

    companion object {
        private const val ACTION_STOP = "com.example.cuota.STOP"
        private const val CHANNEL_ID = "proxy"
        private const val NOTIFICATION_ID = 1
        private const val START_TIMEOUT_MS = 5_000L
        private const val RECENT_LINES = 64
        private const val MAX_PENDING_LOGS = 500
        private val CNTLM_LINE_PREFIX = Regex("^cntlm\\[\\d+\\]: ")
        private const val STOP_TIMEOUT_MS = 1_500L
        private const val LEFTOVER_KILL_DELAY_MS = 200L
        private const val QUOTA_EVENT_INTERVAL_MS = 60_000L
        private const val TUN_MTU = 8500
        private const val TUN_IPV4 = "198.18.0.1"
        private const val TUN_IPV6 = "fc00::1"
        private const val MAPPED_DNS = "198.18.0.2"

        /**
         * Everything except 10.0.0.0/8, 172.16.0.0/12 and 192.168.0.0/16, which
         * keep using the real network so the university and the LAN stay direct.
         */
        private val ROUTES_WITHOUT_PRIVATE_NETWORKS = listOf(
            "0.0.0.0" to 5, "8.0.0.0" to 7, "11.0.0.0" to 8, "12.0.0.0" to 6,
            "16.0.0.0" to 4, "32.0.0.0" to 3, "64.0.0.0" to 2, "128.0.0.0" to 3,
            "160.0.0.0" to 5, "168.0.0.0" to 6, "172.0.0.0" to 12, "172.32.0.0" to 11,
            "172.64.0.0" to 10, "172.128.0.0" to 9, "173.0.0.0" to 8, "174.0.0.0" to 7,
            "176.0.0.0" to 4, "192.0.0.0" to 9, "192.128.0.0" to 11, "192.160.0.0" to 13,
            "192.169.0.0" to 16, "192.170.0.0" to 15, "192.172.0.0" to 14,
            "192.176.0.0" to 12, "192.192.0.0" to 10, "193.0.0.0" to 8, "194.0.0.0" to 7,
            "196.0.0.0" to 6, "200.0.0.0" to 5, "208.0.0.0" to 4, "224.0.0.0" to 3,
        )

        private var pendingRequest: StartRequest? = null
        private var pendingStop: (() -> Unit)? = null

        @Volatile
        var runningProfileId: String? = null
            private set

        /** Sink of the events for Flutter, null while no UI is attached. */
        @Volatile
        var events: ((Map<String, String>) -> Unit)? = null
            set(value) {
                field = value
                if (value != null) flushPendingLogs()
            }

        private val pendingLogs = ArrayDeque<String>()

        /** Lines written with no UI attached wait for one, within a limit. */
        @Synchronized
        fun log(message: String) {
            val sink = events
            if (sink != null) {
                sink(mapOf("type" to "log", "message" to message))
            } else {
                pendingLogs.addLast(message)
                if (pendingLogs.size > MAX_PENDING_LOGS) pendingLogs.removeFirst()
            }
        }

        @Synchronized
        private fun flushPendingLogs() {
            while (pendingLogs.isNotEmpty()) {
                events?.invoke(mapOf("type" to "log", "message" to pendingLogs.removeFirst()))
            }
        }

        fun cntlmPath(context: Context) =
            File(context.applicationInfo.nativeLibraryDir, "libcntlm.so").path

        fun start(context: Context, request: StartRequest) {
            pendingRequest = request
            val intent = Intent(context, CuotaVpnService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context, onStopped: () -> Unit) {
            if (runningProfileId == null) {
                onStopped()
                return
            }
            pendingStop = onStopped
            context.startService(
                Intent(context, CuotaVpnService::class.java).setAction(ACTION_STOP),
            )
        }
    }
}

private fun Process.isAliveCompat(): Boolean =
    try {
        exitValue()
        false
    } catch (_: IllegalThreadStateException) {
        true
    }
