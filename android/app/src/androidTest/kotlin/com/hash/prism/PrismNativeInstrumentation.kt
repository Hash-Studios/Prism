package com.hash.prism

import android.app.Activity
import android.app.Instrumentation
import android.content.ContentUris
import android.graphics.Bitmap
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.hash.prism.pigeon.DownloadItemsResult
import com.hash.prism.pigeon.DownloadRequest
import com.hash.prism.pigeon.OperationResult
import com.hash.prism.pigeon.SaveMediaKind
import com.hash.prism.pigeon.SaveMediaRequest
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.ServerSocket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.UUID

internal class PrismNativeInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }

    override fun onStart() {
        val result = Bundle()
        try {
            verifyWotdWidgetDocuments()
            verifyOfflineTileAssets()
            verifyMediaContract()
            result.putString(OUTPUT_STREAM, "Prism native offline tile and media checks passed\n")
            finish(Activity.RESULT_OK, result)
        } catch (error: Throwable) {
            result.putString(OUTPUT_STREAM, error.stackTraceToString())
            finish(Activity.RESULT_CANCELED, result)
        }
    }

    private fun verifyWotdWidgetDocuments() {
        val document = """{"fields":{"wallpaper_url":{"stringValue":""},"wallpaper_thumb":{"stringValue":"https://cdn.example/preview.jpg"}}}"""
        val wall = wotdWallFromDocument("today", document)
        check(wall == WotdWall("today", "https://cdn.example/preview.jpg", "")) {
            "Protected Wall of the Day must display its preview without treating it as the original"
        }
        check(wotdWallFromDocument("missing", """{"fields":{}}""") == null)
    }

    private fun verifyOfflineTileAssets() {
        val workspace = File.createTempFile("prism-offline-tile", "", targetContext.cacheDir)
        check(workspace.delete() && workspace.mkdir()) { "Could not create offline tile test directory" }
        try {
            val allowedRoot = File(workspace, "allowed").apply { check(mkdirs()) }
            val outsideRoot = File(workspace, "outside").apply { check(mkdirs()) }
            val validUrl = "https://example.com/wall.png"
            val bitmap = Bitmap.createBitmap(3, 3, Bitmap.Config.ARGB_8888)
            val png = try {
                ByteArrayOutputStream().also { output ->
                    check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) { "Could not encode PNG fixture" }
                }.toByteArray()
            } finally {
                bitmap.recycle()
            }
            val retained = File(allowedRoot, "wall.png").apply { writeBytes(png) }
            val validMapping = """{"$validUrl":"${retained.absolutePath}"}"""

            check(OfflineTileAssets.retainedFile(validUrl, validMapping, listOf(allowedRoot)) == retained.canonicalFile) {
                "Valid retained PNG was not resolved to its exact path"
            }
            check(MyTileService.retainedCategoryUrls("[\"$validUrl\"]", validMapping, listOf(allowedRoot)) == listOf(validUrl)) {
                "Valid category mapping was not retained"
            }

            val missing = File(allowedRoot, "missing.png")
            val unsupported = File(allowedRoot, "unsupported.png").apply { writeBytes(byteArrayOf(1, 2, 3)) }
            val malformed = File(allowedRoot, "malformed.png").apply { writeBytes(png.copyOf(20)) }
            val invalidUrls = "[\"https://example.com/missing.png\",\"https://example.com/unsupported.png\"," +
                "\"https://example.com/malformed.png\"]"
            val invalidMapping = """{"https://example.com/missing.png":"${missing.absolutePath}",""" +
                "\"https://example.com/unsupported.png\":\"${unsupported.absolutePath}\"," +
                "\"https://example.com/malformed.png\":\"${malformed.absolutePath}\"}"
            check(MyTileService.retainedCategoryUrls(invalidUrls, invalidMapping, listOf(allowedRoot)).isEmpty()) {
                "Missing or invalid retained image bytes were accepted as category candidates"
            }

            val outside = File(outsideRoot, "wall.png").apply { writeBytes(png) }
            val outsideMapping = """{"$validUrl":"${outside.absolutePath}"}"""
            check(OfflineTileAssets.retainedFile(validUrl, outsideMapping, listOf(allowedRoot)) == null) {
                "Retained image outside the allowed root was accepted"
            }

            val prefixSibling = File(workspace, "allowed-sibling/wall.png").apply {
                check(parentFile?.mkdirs() == true)
                writeBytes(png)
            }
            val siblingMapping = """{"$validUrl":"${prefixSibling.absolutePath}"}"""
            check(OfflineTileAssets.retainedFile(validUrl, siblingMapping, listOf(allowedRoot)) == null) {
                "Path sharing only the allowed-root prefix was accepted"
            }

            check(OfflineTileAssets.retainedFile(validUrl, "not-json", listOf(allowedRoot)) == null) {
                "Malformed retained-path JSON was accepted"
            }
            check(MyTileService.retainedCategoryUrls("not-json", validMapping, listOf(allowedRoot)).isEmpty()) {
                "Malformed category URL JSON was accepted"
            }
            check(MyTileService.retainedCategoryUrls("[\"$validUrl\"]", "{}", listOf(allowedRoot)).isEmpty()) {
                "Category URL without a retained mapping was accepted"
            }
        } finally {
            check(workspace.deleteRecursively()) { "Could not clean offline tile test files" }
        }
    }

    private fun verifyMediaContract() {
        val context = targetContext
        val api = PrismMediaHostApiImpl(context) { callback -> callback(false) }
        val initialIds = imageIds()
        val createdIds = mutableSetOf<Long>()
        val basename = "prism-native-contract-${UUID.randomUUID()}"
        val fixture = File.createTempFile("prism-native-check", ".png", context.cacheDir)
        val bitmap = Bitmap.createBitmap(3, 3, Bitmap.Config.ARGB_8888)
        bitmap.setPixel(0, 0, UUID.randomUUID().hashCode())
        val bytes = ByteArrayOutputStream().also { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }.toByteArray()
        bitmap.recycle()
        fixture.writeBytes(bytes)
        val outcome = runCatching {
            val baseline = await<DownloadItemsResult> { api.listDownloads(it) }
            check(baseline.success) { "Could not read baseline downloads" }
            val saved = await<OperationResult> { api.saveMedia(SaveMediaRequest(fixture.absolutePath, true, SaveMediaKind.WALLPAPER), it) }
            check(saved.success && fixture.exists()) { "Local source was not consumed safely" }
            val savedIds = (imageIds() - initialIds).filter { id ->
                targetContext.contentResolver.openInputStream(ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id))
                    ?.use { it.readBytes().contentEquals(bytes) } == true
            }
            createdIds.addAll(savedIds)
            check(savedIds.size == 1) { "Saved fixture was not published" }

            verifyRejectedSources(api, fixture)

            repeat(2) {
                withResponse(bytes) { url ->
                    val downloaded = await<OperationResult> { callback -> api.enqueueDownload(DownloadRequest(url, basename, false), callback) }
                    check(downloaded.success) { downloaded.message ?: "PNG download failed" }
                }
            }
            val listed = await<DownloadItemsResult> { api.listDownloads(it) }
            val added = listed.items.filterNot { baseline.items.contains(it) }
            check(listed.success && added.size == 2) { "Downloaded images were not listed" }
            check(added.all { File(it).canRead() && File(it).extension == "png" && File(it).name.startsWith(basename) }) {
                "Download paths lost original filenames or PNG type"
            }
            added.forEach { check(File(it).readBytes().contentEquals(bytes)) { "Image bytes changed" } }
            createdIds.addAll(downloadIds(basename, assertMime = true))
            verifyCorruptImages(api, fixture, bytes, basename)

            // Never clear a user's pre-existing emulator media.
            val beforeClear = await<DownloadItemsResult> { api.listDownloads(it) }
            if (baseline.items.isEmpty() && beforeClear.items.all { File(it).name.startsWith(basename) }) {
                check(await<OperationResult> { api.clearDownloads(it) }.success) { "Could not clear downloads" }
                check(await<DownloadItemsResult> { api.listDownloads(it) }.items.isEmpty()) { "Downloads remained after clear" }
            } else sendStatus(0, Bundle().apply { putString(OUTPUT_STREAM, "Skipped clearDownloads: device had pre-existing downloads\n") })
        }
        val cleanup = runCatching {
            api.close()
            fixture.delete()
            createdIds.addAll(downloadIds(basename, assertMime = false))
            for (id in createdIds.intersect(imageIds())) {
                context.contentResolver.delete(ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id), null, null)
            }
        }
        outcome.exceptionOrNull()?.let { failure ->
            cleanup.exceptionOrNull()?.let(failure::addSuppressed)
            throw failure
        }
        cleanup.getOrThrow()
    }

    private fun verifyRejectedSources(api: PrismMediaHostApiImpl, fixture: File) {
        val invalid = await<OperationResult> { api.saveMedia(SaveMediaRequest("relative/path", true, SaveMediaKind.WALLPAPER), it) }
        check(!invalid.success) { "Relative local path accepted" }
        val remoteFile = await<OperationResult> { api.saveMedia(SaveMediaRequest("file://remotehost${fixture.absolutePath}", true, SaveMediaKind.WALLPAPER), it) }
        check(!remoteFile.success) { "Remote file URI authority accepted as a local file" }
        val traversal = await<OperationResult> { api.enqueueDownload(DownloadRequest("https://unused.invalid", "../wall", false), it) }
        check(!traversal.success && traversal.errorCode == "INVALID_FILENAME") { "Unsafe filename accepted" }
        check(PrismHapticType.fromWire("invalid") == null) { "Unknown haptic type accepted" }
    }

    private fun verifyCorruptImages(api: PrismMediaHostApiImpl, fixture: File, bytes: ByteArray, basename: String) {
        val count = imageIds().size
        withResponse("not an image".toByteArray()) { url ->
            check(!await<OperationResult> { api.enqueueDownload(DownloadRequest(url, "$basename-invalid-image", false), it) }.success)
        }
        withResponse(bytes.copyOf(20), bytes.size) { url ->
            check(!await<OperationResult> { api.enqueueDownload(DownloadRequest(url, "$basename-truncated-image", false), it) }.success)
        }
        withResponse(bytes.copyOf(33)) { url ->
            check(!await<OperationResult> { api.enqueueDownload(DownloadRequest(url, "$basename-corrupt-body", false), it) }.success)
        }
        fixture.writeBytes(bytes.copyOf(33))
        check(!await<OperationResult> { api.saveMedia(SaveMediaRequest(fixture.absolutePath, true, SaveMediaKind.WALLPAPER), it) }.success) {
            "PNG header with corrupt body was accepted"
        }
        fixture.writeBytes(bytes)
        check(imageIds().size == count) { "Failed transfer leaked a MediaStore row" }
        check(targetContext.cacheDir.listFiles()?.none { it.name.startsWith("prism-image-") } != false) { "Staging file leaked" }
    }

    private fun imageIds(): Set<Long> {
        val ids = mutableSetOf<Long>()
        targetContext.contentResolver.query(MediaStore.setIncludePending(MediaStore.Images.Media.EXTERNAL_CONTENT_URI), arrayOf(MediaStore.Images.Media._ID), null, null, null)
            ?.use { cursor -> while (cursor.moveToNext()) ids.add(cursor.getLong(0)) }
        return ids
    }

    private fun downloadIds(basename: String, assertMime: Boolean): Set<Long> {
        val ids = mutableSetOf<Long>()
        targetContext.contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.MIME_TYPE), "${MediaStore.Images.Media.DISPLAY_NAME} LIKE ?",
            arrayOf("$basename%"), null)?.use { cursor ->
            while (cursor.moveToNext()) {
                ids.add(cursor.getLong(0))
                if (assertMime) check(cursor.getString(1) == "image/png")
            }
            if (assertMime) check(ids.size == 2)
        } ?: error("Could not query MIME types")
        return ids
    }

    private fun <T> await(action: ((Result<T>) -> Unit) -> Unit): T {
        val latch = CountDownLatch(1)
        var result: Result<T>? = null
        Handler(Looper.getMainLooper()).post { action { result = it; latch.countDown() } }
        check(latch.await(30, TimeUnit.SECONDS)) { "Native callback timed out" }
        return result!!.getOrThrow()
    }

    private fun withResponse(bytes: ByteArray, declaredSize: Int = bytes.size, block: (String) -> Unit) {
        val server = ServerSocket(0)
        val thread = Thread {
            try {
                server.accept().use { socket ->
                    val reader = socket.getInputStream().bufferedReader()
                    var header = reader.readLine()
                    while (!header.isNullOrEmpty()) { header = reader.readLine() }
                    socket.getOutputStream().use { output ->
                        output.write("HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: $declaredSize\r\nConnection: close\r\n\r\n".toByteArray())
                        output.write(bytes)
                    }
                }
            } catch (_: java.io.IOException) { }
        }
        thread.start()
        try { block("http://127.0.0.1:${server.localPort}/image") } finally { server.close(); thread.join(1000) }
    }

    private companion object {
        const val OUTPUT_STREAM = "stream"
    }
}
