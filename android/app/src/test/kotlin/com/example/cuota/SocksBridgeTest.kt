package com.example.cuota

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SocksBridgeTest {
    @Test
    fun requestsBecomeAbsoluteAndCloseTheConnection() {
        val rewritten = rewriteRequestForProxy(
            "GET /a?b=1 HTTP/1.1\r\nHost: example.com\r\nConnection: keep-alive\r\n" +
                "Accept: */*\r\n\r\n",
            "100.64.0.1",
        )

        assertEquals(
            "GET http://example.com/a?b=1 HTTP/1.1\r\nHost: example.com\r\n" +
                "Accept: */*\r\nConnection: close\r\n\r\n",
            rewritten,
        )
    }

    @Test
    fun theTargetIsUsedWithoutHostHeader() {
        val rewritten = rewriteRequestForProxy("GET / HTTP/1.0\r\n\r\n", "example.com")

        assertEquals(
            "GET http://example.com/ HTTP/1.0\r\nConnection: close\r\n\r\n",
            rewritten,
        )
    }

    @Test
    fun otherProtocolsAreNotRewritten() {
        assertNull(rewriteRequestForProxy("hola\r\n\r\n", "example.com"))
    }

    @Test
    fun recognizesTheResponsesOfTheProxy() {
        val blocked = "HTTP/1.1 302 Found\r\nServer: squid\r\n" +
            "Location: http://block.uci.cu/blocked.php?r=DQE\r\n\r\n"

        assertEquals(302, parseStatusCode(blocked))
        assertTrue(isQuotaBlock(blocked))
        assertFalse(isQuotaBlock("HTTP/1.1 403 Forbidden\r\nServer: squid\r\n\r\n"))
    }
}
