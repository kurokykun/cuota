package com.example.cuota

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var consentRequest: CuotaVpnService.StartRequest? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "cuota/vpn").setMethodCallHandler(::onMethodCall)
        EventChannel(messenger, "cuota/vpn/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    CuotaVpnService.events = { event ->
                        mainHandler.post { sink.success(event) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    CuotaVpnService.events = null
                }
            },
        )
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "computeHashes" -> computeHashes(
                call.argument<String>("username")!!,
                call.argument<String>("domain")!!,
                call.argument<String>("password")!!,
                result,
            )
            "start" -> start(
                CuotaVpnService.StartRequest(
                    call.argument<String>("config")!!,
                    call.argument<Int>("port")!!,
                    call.argument<String>("profileId")!!,
                ) { error ->
                    mainHandler.post {
                        if (error == null) result.success(null) else result.error("start", error, null)
                    }
                },
            )
            "stop" -> CuotaVpnService.stop(this) { mainHandler.post { result.success(null) } }
            "runningProfileId" -> result.success(CuotaVpnService.runningProfileId)
            "saveLog" -> saveLog(
                call.argument<String>("name")!!,
                call.argument<String>("contents")!!,
                result,
            )
            else -> result.notImplemented()
        }
    }

    /** MediaStore reaches the public downloads folder without any permission. */
    private fun saveLog(name: String, contents: String, result: MethodChannel.Result) {
        thread {
            try {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IOException("No uri")
                contentResolver.openOutputStream(uri)?.use { it.write(contents.toByteArray()) }
                    ?: throw IOException("No stream")
                mainHandler.post { result.success("Descargas/$name") }
            } catch (_: IOException) {
                mainHandler.post { result.error("saveLog", "No se pudo guardar", null) }
            }
        }
    }

    /** The password goes through stdin so it never shows up in the process list. */
    private fun computeHashes(
        username: String,
        domain: String,
        password: String,
        result: MethodChannel.Result,
    ) {
        thread {
            val emptyConfig = File(cacheDir, "empty.conf")
            try {
                emptyConfig.writeText("")
                val process = ProcessBuilder(
                    CuotaVpnService.cntlmPath(this),
                    "-c", emptyConfig.path,
                    "-H",
                    "-u", username,
                    "-d", domain,
                ).redirectErrorStream(true).start()
                process.outputStream.bufferedWriter().use { it.write("$password\n") }
                val output = process.inputStream.bufferedReader().readText()
                process.waitFor()
                mainHandler.post { result.success(output) }
            } catch (_: IOException) {
                mainHandler.post {
                    result.error("hashes", "No se pudo preparar la contraseña", null)
                }
            } finally {
                emptyConfig.delete()
            }
        }
    }

    /** Android asks the user to authorize the VPN the first time. */
    private fun start(request: CuotaVpnService.StartRequest) {
        requestNotificationPermission()
        val consent = VpnService.prepare(this)
        if (consent == null) {
            CuotaVpnService.start(this, request)
        } else {
            consentRequest = request
            startActivityForResult(consent, REQUEST_VPN_CONSENT)
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
        }
    }

    @Deprecated("Deprecated in the framework, still the one FlutterActivity forwards")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_VPN_CONSENT) return
        val request = consentRequest ?: return
        consentRequest = null
        if (resultCode == Activity.RESULT_OK) {
            CuotaVpnService.start(this, request)
        } else {
            request.onResult("Debe autorizar la VPN para enviar el tráfico por el proxy")
        }
    }

    private companion object {
        const val REQUEST_VPN_CONSENT = 1001
        const val REQUEST_NOTIFICATIONS = 1002
    }
}
