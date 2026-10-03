package com.hash.prism

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.net.ServerSocket
import java.util.concurrent.RejectedExecutionException

private const val IMAGE_PATH = "/image"

internal class PrismNativeTest {
    @Test internal fun filenamesRejectTraversalControlsAndUtf8Overflow() {
        for (name in listOf("", " ", ".", "..", "../wall", "folder/wall", "folder\\wall", "wall\n", "\u0000wall", "🎨".repeat(51))) {
            assertThrows(IllegalArgumentException::class.java) { PrismImageTransfer.validateFilename(name) }
        }
        assertEquals("wallhaven-abc (1).png", PrismImageTransfer.validateFilename("wallhaven-abc (1).png"))
        val longestStem = "🎨".repeat(50)
        assertEquals(longestStem, PrismImageTransfer.validateFilename(longestStem))
        assertEquals("$longestStem (1).jpeg", PrismImageTransfer.validateStoredFilename("$longestStem (1).jpeg"))
        assertThrows(IllegalArgumentException::class.java) { PrismImageTransfer.validateStoredFilename("🎨".repeat(64)) }
    }

    @Test internal fun copyRejectsEmptyOversizedAndInterruptedStreams() {
        assertThrows(IOException::class.java) { PrismImageTransfer.copy(ByteArrayInputStream(byteArrayOf()), ByteArrayOutputStream()) }
        assertThrows(IOException::class.java) { PrismImageTransfer.copy(ByteArrayInputStream(byteArrayOf(1, 2)), ByteArrayOutputStream(), 1) }
        Thread.currentThread().interrupt()
        try {
            assertThrows(IOException::class.java) { PrismImageTransfer.copy(ByteArrayInputStream(byteArrayOf(1)), ByteArrayOutputStream()) }
        } finally { Thread.interrupted() }
        val output = ByteArrayOutputStream()
        assertEquals(2L, PrismImageTransfer.copy(ByteArrayInputStream(byteArrayOf(1, 2)), output))
        assertArrayEquals(byteArrayOf(1, 2), output.toByteArray())
    }

    @Test internal fun downloadsFollowRelativeRedirectsAndRejectBadResponses() {
        val server = TestServer { path, _ -> when (path) {
            IMAGE_PATH -> Response(body = byteArrayOf(1, 2, 3))
            "/redirect" -> Response(code = 302, location = IMAGE_PATH)
            "/loop" -> Response(code = 302, location = "/loop")
            "/unsafe" -> Response(code = 302, location = "file:///etc/passwd")
            "/truncated" -> Response(body = byteArrayOf(1, 2, 3), declaredSize = 30)
            else -> Response(code = 404)
        } }
        val file = File.createTempFile("prism-transfer-test", ".tmp")
        try {
            val url = server.url
            PrismImageTransfer.download("$url/redirect", file)
            assertArrayEquals(byteArrayOf(1, 2, 3), file.readBytes())
            for (path in listOf("/loop", "/truncated", "/missing")) {
                assertThrows(IOException::class.java) { PrismImageTransfer.download("$url$path", file) }
            }
            assertThrows(IllegalArgumentException::class.java) { PrismImageTransfer.download("$url/unsafe", file) }
            assertThrows(IllegalArgumentException::class.java) { PrismImageTransfer.openConnection("file:///etc/passwd") }
        } finally { server.close(); file.delete() }
    }

    @Test internal fun redirectsDoNotLeakAuthorizationToAnotherOrigin() {
        var authorization: String? = "not-called"
        val destination = TestServer { _, headers ->
            authorization = headers["authorization"]
            Response(body = byteArrayOf(1))
        }
        val origin = TestServer { _, _ -> Response(code = 302, location = "${destination.url}$IMAGE_PATH") }
        try {
            val connection = PrismImageTransfer.openConnection("${origin.url}/", mapOf("Authorization" to "secret"))
            try { connection.inputStream.use { it.readBytes() } } finally { connection.disconnect() }
            assertNull(authorization)
        } finally { origin.close(); destination.close() }
    }

    @Test internal fun permissionsCoalesceResolveExactlyOnceAndCancelAtDetach() {
        val gate = LegacyStoragePermissionGate()
        var prompts = 0
        val results = mutableListOf<Boolean>()
        repeat(2) { gate.request({ results.add(it) }) { prompts++ } }
        assertEquals(1, prompts)
        gate.resolve(true)
        gate.resolve(false)
        assertEquals(listOf(true, true), results)
        gate.request({ results.add(it) }) { prompts++ }
        assertEquals(2, prompts)
        gate.close()
        gate.resolve(true)
        gate.request({ results.add(it) }) { prompts++ }
        assertEquals(listOf(true, true, false, false), results)
        assertEquals(2, prompts)
    }

    @Test internal fun failedPermissionLaunchDeniesAndAllowsRetry() {
        val gate = LegacyStoragePermissionGate()
        val results = mutableListOf<Boolean>()
        gate.request({ results.add(it) }) { throw IllegalStateException("detached") }
        gate.request({ results.add(it) }) { gate.resolve(false) }
        assertEquals(listOf(false, false), results)
    }

    @Test internal fun nativeEnumsRejectUnknownWireValues() {
        assertEquals(PrismHapticType.TAP, PrismHapticType.fromWire("tap"))
        assertNull(PrismHapticType.fromWire("unknown"))
        assertNull(PrismHapticType.fromWire(null))
        assertNull(PrismHapticType.fromWire(42))
        assertEquals(TileWallpaperTarget.BOTH, TileWallpaperTarget.parse(null))
        assertEquals(TileWallpaperTarget.LOCK, TileWallpaperTarget.parse("lock"))
        assertThrows(IllegalArgumentException::class.java) { TileWallpaperTarget.parse("invalid") }
    }

    @Test internal fun rejectedMediaTasksReturnReadableBusyFailures() {
        val rejection = RejectedExecutionException("executor internals")
        assertEquals("MEDIA_BUSY", mediaFailureCode("DOWNLOAD_FAILED", rejection))
        assertEquals("Another media operation is in progress. Please try again.", mediaFailureMessage(rejection))
        val failure = IOException("Could not publish image")
        assertEquals("SAVE_FAILED", mediaFailureCode("SAVE_FAILED", failure))
        assertEquals(failure.message, mediaFailureMessage(failure))
    }

    private data class Response(val code: Int = 200, val body: ByteArray = byteArrayOf(), val declaredSize: Int = body.size, val location: String? = null)

    private class TestServer(private val response: (String, Map<String, String>) -> Response) : AutoCloseable {
        private val server = ServerSocket(0)
        val url = "http://127.0.0.1:${server.localPort}"
        private val thread = Thread {
            while (!server.isClosed) {
                try {
                    server.accept().use { socket ->
                        val reader = socket.getInputStream().bufferedReader()
                        val path = reader.readLine().split(' ')[1]
                        val headers = mutableMapOf<String, String>()
                        while (true) {
                            val line = reader.readLine() ?: break
                            if (line.isEmpty()) break
                            headers[line.substringBefore(':').lowercase()] = line.substringAfter(':').trim()
                        }
                        val reply = response(path, headers)
                        socket.getOutputStream().use { output ->
                            val location = reply.location?.let { "Location: $it\r\n" }.orEmpty()
                            output.write("HTTP/1.1 ${reply.code} Response\r\n${location}Content-Length: ${reply.declaredSize}\r\nConnection: close\r\n\r\n".toByteArray())
                            output.write(reply.body)
                        }
                    }
                } catch (_: IOException) { }
            }
        }.apply { isDaemon = true; start() }

        override fun close() { server.close(); thread.join(1000) }
    }
}
