package com.hash.prism

import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

internal class PrismImageTransferTest {
    private val body = ByteArray(4096) { it.toByte() }
    private val requests = AtomicInteger()
    private lateinit var server: ServerSocket
    private lateinit var file: File

    @Before
    fun setUp() {
        server = ServerSocket(0, 8, InetAddress.getLoopbackAddress())
        file = File.createTempFile("prism-transfer-", ".tmp")
    }

    @After
    fun tearDown() {
        server.close()
        file.delete()
    }

    /** Answers each request with [respond]: the attempt number and the raw socket output. */
    private fun serve(respond: (attempt: Int, output: OutputStream) -> Unit): String {
        thread(isDaemon = true) {
            while (!server.isClosed) {
                val socket = try { server.accept() } catch (_: IOException) { return@thread }
                socket.use {
                    val reader = it.getInputStream().bufferedReader()
                    while (reader.readLine()?.isNotEmpty() == true) Unit
                    respond(requests.incrementAndGet(), it.getOutputStream())
                    it.getOutputStream().flush()
                }
            }
        }
        return "http://127.0.0.1:${server.localPort}/wall"
    }

    private fun OutputStream.head(status: String, length: Int) =
        write("HTTP/1.1 $status\r\nContent-Length: $length\r\nConnection: close\r\n\r\n".toByteArray())

    @Test
    fun `a dropped first response is downloaded on the second try (#547)`() {
        val link = serve { attempt, output ->
            output.head("200 OK", body.size)
            output.write(if (attempt == 1) body.copyOf(100) else body)
        }

        PrismImageTransfer.download(link, file)

        assertEquals(2, requests.get())
        assertArrayEquals(body, file.readBytes())
    }

    @Test
    fun `a server error is tried once more`() {
        val link = serve { attempt, output ->
            if (attempt == 1) {
                output.head("503 Service Unavailable", 0)
            } else {
                output.head("200 OK", body.size)
                output.write(body)
            }
        }

        PrismImageTransfer.download(link, file)

        assertEquals(2, requests.get())
    }

    @Test
    fun `a missing image is not requested again`() {
        val link = serve { _, output -> output.head("404 Not Found", 0) }

        assertThrows(IOException::class.java) { PrismImageTransfer.download(link, file) }
        assertEquals(1, requests.get())
    }

    @Test
    fun `two dropped responses fail after one retry`() {
        val link = serve { _, output ->
            output.head("200 OK", body.size)
            output.write(body.copyOf(100))
        }

        assertThrows(IOException::class.java) { PrismImageTransfer.download(link, file) }
        assertEquals(2, requests.get())
    }
}
