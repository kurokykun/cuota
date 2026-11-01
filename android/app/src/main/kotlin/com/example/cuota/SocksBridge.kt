package com.example.cuota

import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * SOCKS5 server for the tunnel that turns each connection into what the upstream
 * Squid accepts: plain HTTP for port 80, where it rejects CONNECT, and CONNECT
 * through cntlm for everything else.
 */
class SocksBridge(
    private val proxyPort: Int,
    private val onQuotaBlocked: () -> Unit,
    private val onLog: (String) -> Unit,
) : Closeable {
    private val server = ServerSocket(0, 128, InetAddress.getByName("127.0.0.1"))
    private val pool: ExecutorService = Executors.newCachedThreadPool()
    private val openSockets = ConcurrentHashMap.newKeySet<Socket>()

    @Volatile
    private var closed = false

    val port: Int get() = server.localPort

    fun start() {
        pool.execute {
            try {
                while (true) {
                    val client = server.accept()
                    pool.execute { handle(client) }
                }
            } catch (_: IOException) {
                // The server socket was closed.
            }
        }
    }

    /**
     * Blocking socket calls ignore thread interruption: only closing the sockets
     * ends the connections, and cntlm does not exit while it has any open.
     */
    override fun close() {
        closed = true
        runCatching { server.close() }
        openSockets.forEach { socket -> runCatching { socket.close() } }
        pool.shutdownNow()
    }

    private inline fun <T> tracked(socket: Socket, block: () -> T): T {
        openSockets.add(socket)
        try {
            // close() may have run before this socket was registered.
            if (closed) throw IOException("Bridge closed")
            return block()
        } finally {
            openSockets.remove(socket)
            runCatching { socket.close() }
        }
    }

    private fun handle(client: Socket) {
        tracked(client) {
            try {
                client.soTimeout = HANDSHAKE_TIMEOUT_MS
                val input = client.getInputStream()
                val output = client.getOutputStream()
                val target = readSocksRequest(input, output) ?: return
                if (target.port == 80) {
                    forwardHttp(client, input, output, target)
                } else {
                    forwardConnect(client, input, output, target)
                }
            } catch (_: IOException) {
                // Either side went away, closing the sockets is all that is left.
            }
        }
    }

    private fun readSocksRequest(input: InputStream, output: OutputStream): Target? {
        if (input.read() != SOCKS_VERSION) return null
        val methods = input.read()
        if (methods < 0) return null
        input.readExactly(methods)
        output.write(byteArrayOf(SOCKS_VERSION.toByte(), 0))

        input.readExactly(1)
        val command = input.read()
        input.readExactly(1)
        val host = when (input.read()) {
            ADDRESS_IPV4 -> InetAddress.getByAddress(input.readExactly(4)).hostAddress
            ADDRESS_DOMAIN -> String(input.readExactly(input.read()), Charsets.US_ASCII)
            ADDRESS_IPV6 -> "[${InetAddress.getByAddress(input.readExactly(16)).hostAddress}]"
            else -> return null
        } ?: return null
        val portBytes = input.readExactly(2)
        val port = (portBytes[0].toInt() and 0xff shl 8) or (portBytes[1].toInt() and 0xff)
        if (command != COMMAND_CONNECT) {
            reply(output, REPLY_COMMAND_NOT_SUPPORTED)
            return null
        }
        return Target(host, port)
    }

    private fun forwardConnect(
        client: Socket,
        input: InputStream,
        output: OutputStream,
        target: Target,
    ) {
        val proxy = openProxy()
        tracked(proxy) {
            val proxyInput = proxy.getInputStream()
            val authority = "${target.host}:${target.port}"
            proxy.getOutputStream().write(
                "CONNECT $authority HTTP/1.1\r\nHost: $authority\r\n\r\n"
                    .toByteArray(Charsets.ISO_8859_1),
            )
            val head = readHttpHead(proxyInput)?.head
            val status = head?.let(::parseStatusCode)
            if (status !in 200..299) {
                if (head != null && isQuotaBlock(head)) onQuotaBlocked()
                onLog("CONNECT $authority rechazado: ${status ?: "sin respuesta"}")
                reply(output, REPLY_NOT_ALLOWED)
                return@tracked
            }
            reply(output, REPLY_SUCCESS)
            relay(client, input, output, proxy)
        }
    }

    private fun forwardHttp(
        client: Socket,
        input: InputStream,
        output: OutputStream,
        target: Target,
    ) {
        reply(output, REPLY_SUCCESS)
        val request = readHttpHead(input) ?: return
        val rewritten = rewriteRequestForProxy(request.head, target.host) ?: return
        val proxy = openProxy()
        tracked(proxy) {
            val proxyOutput = proxy.getOutputStream()
            proxyOutput.write(rewritten.toByteArray(Charsets.ISO_8859_1))
            proxyOutput.write(request.remainder)
            relay(client, input, output, proxy)
        }
    }

    private fun openProxy(): Socket =
        Socket(InetAddress.getByName("127.0.0.1"), proxyPort).apply {
            soTimeout = HANDSHAKE_TIMEOUT_MS
        }

    private fun relay(
        client: Socket,
        clientInput: InputStream,
        clientOutput: OutputStream,
        proxy: Socket,
    ) {
        client.soTimeout = 0
        proxy.soTimeout = 0
        val upload = pool.submit {
            pump(clientInput, proxy.getOutputStream())
            runCatching { proxy.shutdownOutput() }
        }
        pump(proxy.getInputStream(), clientOutput)
        // Nothing else can come back: end the other direction as well.
        runCatching { client.shutdownOutput() }
        upload.cancel(true)
    }

    private fun pump(from: InputStream, to: OutputStream) {
        val buffer = ByteArray(BUFFER_SIZE)
        try {
            while (true) {
                val count = from.read(buffer)
                if (count < 0) return
                to.write(buffer, 0, count)
                to.flush()
            }
        } catch (_: IOException) {
            // Handled by the caller, which closes both sides.
        }
    }

    private fun reply(output: OutputStream, code: Int) {
        output.write(byteArrayOf(SOCKS_VERSION.toByte(), code.toByte(), 0, ADDRESS_IPV4.toByte(), 0, 0, 0, 0, 0, 0))
    }

    private fun InputStream.readExactly(count: Int): ByteArray {
        val bytes = ByteArray(count)
        var offset = 0
        while (offset < count) {
            val read = read(bytes, offset, count - offset)
            if (read < 0) throw IOException("Unexpected end of stream")
            offset += read
        }
        return bytes
    }

    private data class Target(val host: String, val port: Int)

    private companion object {
        const val SOCKS_VERSION = 5
        const val COMMAND_CONNECT = 1
        const val ADDRESS_IPV4 = 1
        const val ADDRESS_DOMAIN = 3
        const val ADDRESS_IPV6 = 4
        const val REPLY_SUCCESS = 0
        const val REPLY_NOT_ALLOWED = 2
        const val REPLY_COMMAND_NOT_SUPPORTED = 7
        const val HANDSHAKE_TIMEOUT_MS = 30_000
        const val BUFFER_SIZE = 16 * 1024
    }
}

internal class HttpHead(val head: String, val remainder: ByteArray)

private const val MAX_HEAD_SIZE = 64 * 1024

/** Reads up to the end of the HTTP headers, or null if the stream is not HTTP. */
internal fun readHttpHead(input: InputStream): HttpHead? {
    val data = ByteArrayOutputStream()
    val buffer = ByteArray(4096)
    while (data.size() < MAX_HEAD_SIZE) {
        val count = input.read(buffer)
        if (count < 0) return null
        data.write(buffer, 0, count)
        val bytes = data.toByteArray()
        val end = String(bytes, Charsets.ISO_8859_1).indexOf("\r\n\r\n")
        if (end >= 0) {
            val headEnd = end + 4
            return HttpHead(
                String(bytes, 0, headEnd, Charsets.ISO_8859_1),
                bytes.copyOfRange(headEnd, bytes.size),
            )
        }
    }
    return null
}

internal fun parseStatusCode(head: String): Int? =
    head.lineSequence().firstOrNull()?.split(' ')?.getOrNull(1)?.toIntOrNull()

/** The university proxy answers with a redirect to this host when it blocks. */
internal fun isQuotaBlock(head: String): Boolean =
    head.lineSequence().any {
        it.startsWith("Location:", ignoreCase = true) && it.contains("block.uci.cu")
    }

/**
 * Converts a request made for an origin server into one for a proxy. Connections
 * are closed after one request: the next one on the same connection would come
 * in origin form again and there would be no chance to rewrite it.
 */
internal fun rewriteRequestForProxy(head: String, targetHost: String): String? {
    val lines = head.removeSuffix("\r\n\r\n").split("\r\n")
    val parts = lines.first().split(' ')
    if (parts.size != 3 || !parts[2].startsWith("HTTP/") || !parts[1].startsWith("/")) return null

    val headers = lines.drop(1)
    val host = headers
        .firstOrNull { it.startsWith("Host:", ignoreCase = true) }
        ?.substringAfter(':')
        ?.trim()
        ?: targetHost
    val kept = headers.filterNot { line ->
        val name = line.substringBefore(':').trim().lowercase()
        name == "connection" || name == "proxy-connection" || name == "keep-alive"
    }
    return buildString {
        append("${parts[0]} http://$host${parts[1]} ${parts[2]}\r\n")
        kept.forEach { append(it).append("\r\n") }
        append("Connection: close\r\n\r\n")
    }
}
