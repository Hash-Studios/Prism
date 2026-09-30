package com.hash.prism

import android.content.ContentResolver
import android.content.Context
import android.os.Build
import android.os.Environment
import com.hash.prism.pigeon.SaveMediaKind
import com.hash.prism.pigeon.SaveMediaRequest
import java.io.ByteArrayInputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLConnection
import java.net.URLStreamHandler
import java.nio.file.Files
import java.util.Base64

private val png = Base64.getDecoder().decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/8ioAAAAASUVORK5CYII=",
)

private data class Route(
    val bytes: ByteArray,
    val contentType: String = "image/png",
    val contentLength: Long = bytes.size.toLong(),
    val finalUrl: String? = null,
    val failRead: Boolean = false,
    val responseCode: Int = 200,
    val contentEncoding: String? = null,
)

private object FakeHttp {
    val routes = mutableMapOf<String, Route>()
    var lastInput: TrackingInput? = null
    var lastConnection: FakeConnection? = null

    fun install() {
        URL.setURLStreamHandlerFactory { protocol ->
            if (protocol != "media-test") null else object : URLStreamHandler() {
                override fun openConnection(url: URL): URLConnection {
                    lastInput = null
                    return FakeConnection(url, routes[url.path]!!).also { lastConnection = it }
                }
            }
        }
    }
}

private class TrackingInput(private val route: Route) : InputStream() {
    private val delegate = ByteArrayInputStream(route.bytes)
    var closed = false
    override fun read(): Int {
        if (route.failRead) throw IOException("injected source failure")
        return delegate.read()
    }
    override fun read(bytes: ByteArray, offset: Int, length: Int): Int {
        if (route.failRead) throw IOException("injected source failure")
        return delegate.read(bytes, offset, length)
    }
    override fun close() { closed = true; delegate.close() }
}

private class FakeConnection(url: URL, private val route: Route) : HttpURLConnection(url) {
    var disconnected = false
    override fun connect() { connected = true }
    override fun disconnect() { disconnected = true; connected = false }
    override fun usingProxy(): Boolean = false
    override fun getResponseCode(): Int = route.responseCode
    override fun getContentType(): String = route.contentType
    override fun getContentLengthLong(): Long = route.contentLength
    override fun getContentEncoding(): String? = route.contentEncoding
    override fun getURL(): URL = route.finalUrl?.let(::URL) ?: url
    override fun getInputStream(): InputStream = TrackingInput(route).also { FakeHttp.lastInput = it }
}

private val saveMethod = PrismMediaHostApiImpl::class.java
    .getDeclaredMethod("saveMediaInternal", SaveMediaRequest::class.java)
    .apply { isAccessible = true }

private fun save(context: Context, request: SaveMediaRequest) =
    saveMethod.invoke(PrismMediaHostApiImpl(context), request) as com.hash.prism.pigeon.OperationResult

private fun context(root: File, resolver: ContentResolver = ContentResolver()) = Context(
    contentResolver = resolver,
    cacheDir = File(root, "cache").apply { mkdirs() },
)

private fun assertThat(value: Boolean, message: String) {
    check(value) { message }
}

private fun runCase(name: String, failures: MutableList<String>, test: () -> Unit) {
    try {
        test()
        println("PASS $name")
    } catch (error: Throwable) {
        failures += name
        System.err.println("FAIL $name: ${error.message}")
    }
}

private class FailingInput(private val bytes: ByteArray) : InputStream() {
    private var offset = 0
    override fun read(): Int {
        if (offset >= 8) throw IOException("injected source failure")
        return bytes[offset++].toInt() and 255
    }
    override fun read(target: ByteArray, start: Int, length: Int): Int {
        if (offset >= 8) throw IOException("injected source failure")
        val count = minOf(length, 8 - offset)
        bytes.copyInto(target, start, offset, offset + count)
        offset += count
        return count
    }
}

fun main() {
    FakeHttp.install()
    val root = Files.createTempDirectory("prism-media-harness-").toFile()
    val failures = mutableListOf<String>()
    try {
        Build.VERSION.SDK_INT = 35

        runCase("escaped local file URI preserves PNG bytes and MIME", failures) {
            val local = File(root, "wall paper.png").apply { writeBytes(png) }
            val fileUri = local.toURI().toString().replaceFirst("file:/", "file:///")
            val resolver = ContentResolver()
            val result = save(context(root, resolver), SaveMediaRequest(fileUri, true, SaveMediaKind.wallpaper))
            assertThat(result.success, "encoded file URI must save: $result")
            assertThat(resolver.outputBytes.toByteArray().contentEquals(png), "local PNG bytes must be preserved")
            assertThat(resolver.insertedValues?.get("mime_type") == "image/png", "local PNG MIME must be detected")
            assertThat(resolver.insertedValues?.get("is_pending") == 1, "MediaStore row must start pending")
            assertThat(resolver.updateCount == 1, "complete row must be published")
        }

        runCase("plain local PNG publishes a complete pending MediaStore row", failures) {
            val local = File(root, "plain-local.png").apply { writeBytes(png) }
            val resolver = ContentResolver()
            val result = save(context(root, resolver), SaveMediaRequest(local.path, true, SaveMediaKind.wallpaper))
            assertThat(result.success, "plain local path must save: $result")
            assertThat(resolver.insertedValues?.get("is_pending") == 1, "row must be inserted pending")
            assertThat(resolver.updatedValues?.get("is_pending") == 0, "row must be published after copy")
            assertThat(resolver.outputBytes.toByteArray().contentEquals(png), "published row must contain original PNG bytes")
        }

        runCase("empty and malformed image bodies fail loading", failures) {
            FakeHttp.routes["/empty.png"] = Route(byteArrayOf(), contentLength = 0)
            FakeHttp.routes["/html.png"] = Route("<html>bad</html>".toByteArray())
            for (path in listOf("empty.png", "html.png")) {
                val result = save(
                    context(root),
                    SaveMediaRequest("media-test://host/$path", false, SaveMediaKind.wallpaper),
                )
                assertThat(result.errorCode == "FAILED_TO_LOAD_BITMAP", "$path should fail with load error: $result")
            }
        }

        runCase("short response fails against declared content length", failures) {
            FakeHttp.routes["/short.png"] = Route(png.copyOf(20), contentLength = png.size.toLong())
            val result = save(
                context(root),
                SaveMediaRequest("media-test://host/short.png", false, SaveMediaKind.wallpaper),
            )
            assertThat(result.errorCode == "FAILED_TO_LOAD_BITMAP", "short response must fail loading: $result")
        }

        runCase("identity-encoded short response still checks content length", failures) {
            FakeHttp.routes["/identity-short.png"] = Route(
                png.copyOf(40),
                contentLength = png.size.toLong(),
                contentEncoding = "identity",
            )
            val result = save(
                context(root),
                SaveMediaRequest("media-test://host/identity-short.png", false, SaveMediaKind.wallpaper),
            )
            assertThat(result.errorCode == "FAILED_TO_LOAD_BITMAP", "identity response length mismatch must fail: $result")
        }

        runCase("redirect final extension identifies octet-stream PNG", failures) {
            FakeHttp.routes["/redirect"] = Route(
                png,
                contentType = "application/octet-stream",
                finalUrl = "media-test://cdn/images/final.png",
            )
            val resolver = ContentResolver()
            val result = save(context(root, resolver), SaveMediaRequest("media-test://origin/redirect", false, SaveMediaKind.wallpaper))
            assertThat(result.success, "redirect image must save")
            assertThat(resolver.insertedValues?.get("mime_type") == "image/png", "redirect URL extension must recover MIME")
            assertThat((resolver.insertedValues?.get("display_name") as String).endsWith(".png"), "filename must match MIME")
            assertThat(FakeHttp.lastInput?.closed == true, "HTTP source stream must close after success")
            assertThat(FakeHttp.lastConnection?.disconnected == true, "HTTP connection must disconnect after success")
        }

        runCase("non-2xx response preserves load error and disconnects", failures) {
            FakeHttp.routes["/not-found.png"] = Route(png, responseCode = 404)
            val resolver = ContentResolver()
            val result = save(context(root, resolver), SaveMediaRequest("media-test://host/not-found.png", false, SaveMediaKind.wallpaper))
            assertThat(result.errorCode == "FAILED_TO_LOAD_BITMAP", "HTTP errors must retain load code")
            assertThat(resolver.insertedValues == null, "HTTP errors must not create MediaStore rows")
            assertThat(FakeHttp.lastInput == null, "HTTP error body must not be treated as image input")
            assertThat(FakeHttp.lastConnection?.disconnected == true, "HTTP error connection must disconnect")
        }

        runCase("source read failure preserves load error and closes streams", failures) {
            FakeHttp.routes["/broken.png"] = Route(png, failRead = true)
            val resolver = ContentResolver()
            val result = save(context(root, resolver), SaveMediaRequest("media-test://host/broken.png", false, SaveMediaKind.wallpaper))
            assertThat(result.errorCode == "FAILED_TO_LOAD_BITMAP", "source failure must retain load code")
            assertThat(FakeHttp.lastInput?.closed == true, "source stream must close after failure")
            assertThat(FakeHttp.lastConnection?.disconnected == true, "source failure connection must disconnect")
            assertThat(resolver.insertedValues == null, "invalid source must not create a MediaStore row")
            assertThat(File(root, "cache").listFiles().orEmpty().isEmpty(), "staging file must be removed")
        }

        runCase("partial MediaStore copy is deleted and output closes", failures) {
            FakeHttp.routes["/write.png"] = Route(png)
            val resolver = ContentResolver().apply { failOutputAfterBytes = 8 }
            val result = save(context(root, resolver), SaveMediaRequest("media-test://host/write.png", false, SaveMediaKind.wallpaper))
            assertThat(result.errorCode == "SAVE_FAILED", "destination error must retain save code")
            assertThat(resolver.deleteCount == 1, "partial MediaStore row must be deleted")
            assertThat(resolver.outputClosed, "failed destination stream must close")
        }

        runCase("failed publication deletes pending MediaStore row", failures) {
            FakeHttp.routes["/publish.png"] = Route(png)
            val resolver = ContentResolver().apply { failPublish = true }
            val result = save(context(root, resolver), SaveMediaRequest("media-test://host/publish.png", false, SaveMediaKind.wallpaper))
            assertThat(result.errorCode == "SAVE_FAILED", "publish failure must report save failure")
            assertThat(resolver.deleteCount == 1, "unpublished row must be deleted")
        }

        runCase("pre-Q save preserves bytes and extension", failures) {
            Build.VERSION.SDK_INT = 28
            Environment.externalStorageRoot = File(root, "external")
            val local = File(root, "legacy.png").apply { writeBytes(png) }
            val result = save(context(root), SaveMediaRequest(local.path, true, SaveMediaKind.wallpaper))
            val files = File(Environment.externalStorageRoot, "Pictures/Prism").listFiles().orEmpty()
            assertThat(result.success, "pre-Q save must succeed: $result")
            assertThat(files.size == 1 && files.single().extension == "png", "pre-Q save must use PNG extension")
            assertThat(files.single().readBytes().contentEquals(png), "pre-Q save must preserve original bytes")
        }

        runCase("pre-Q partial destination file is removed", failures) {
            Build.VERSION.SDK_INT = 28
            Environment.externalStorageRoot = File(root, "legacy-failure")
            val writer = PrismMediaHostApiImpl::class.java
                .getDeclaredMethod("writeToPictures", InputStream::class.java, String::class.java, String::class.java)
                .apply { isAccessible = true }
            val result = writer.invoke(PrismMediaHostApiImpl(context(root)), FailingInput(png), "image/png", "Prism") as Boolean
            val files = File(Environment.externalStorageRoot, "Pictures/Prism").listFiles().orEmpty()
            assertThat(!result, "pre-Q partial copy must fail")
            assertThat(files.isEmpty(), "pre-Q partial destination must be deleted")
        }

        if (failures.isNotEmpty()) error("${failures.size} media regression case(s) failed: ${failures.joinToString()}")
        println("media regression harness passed")
    } finally {
        root.deleteRecursively()
    }
}
