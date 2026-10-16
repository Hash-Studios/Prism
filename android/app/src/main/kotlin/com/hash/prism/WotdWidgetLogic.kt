package com.hash.prism

import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.URLEncoder
import java.security.MessageDigest
import org.json.JSONObject

internal data class WotdWall(val id: String, val url: String) {
    val key: String get() = id.ifEmpty { url }
}

internal fun monotonicMillis(): Long = System.nanoTime() / 1_000_000L

internal fun timeoutWithin(capMs: Int, deadlineMs: Long, nowMs: Long): Int {
    val remaining = deadlineMs - nowMs
    if (remaining <= 0) throw IOException("Widget update ran out of time")
    return minOf(capMs.toLong(), remaining).toInt()
}

internal fun copyWithin(input: InputStream, output: OutputStream, maxBytes: Long, deadlineMs: Long, now: () -> Long = ::monotonicMillis): Long {
    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
    var bytes = 0L
    while (true) {
        if (now() > deadlineMs) throw IOException("Widget update ran out of time")
        val count = input.read(buffer)
        if (count < 0) break
        bytes += count
        if (bytes > maxBytes) throw IOException("Response exceeds size limit")
        output.write(buffer, 0, count)
    }
    if (bytes == 0L) throw IOException("Response is empty")
    return bytes
}

internal fun wallpaperSampleSize(width: Int, height: Int, targetWidth: Int, targetHeight: Int, maxPixels: Long = 12_000_000L): Int {
    if (width <= 0 || height <= 0) return 1
    var sample = 1
    if (targetWidth > 0 && targetHeight > 0) {
        while (width / (sample * 2) >= targetWidth && height / (sample * 2) >= targetHeight) sample *= 2
    }
    while ((width.toLong() / sample) * (height.toLong() / sample) > maxPixels) sample *= 2
    return sample
}

private fun encodePart(value: String): String = URLEncoder.encode(value, "UTF-8").replace("+", "%20")

internal fun firestoreDocumentUrl(projectId: String, collection: String, documentId: String, apiKey: String): String =
    "https://firestore.googleapis.com/v1/projects/${encodePart(projectId)}/databases/(default)/documents/" +
        "${encodePart(collection)}/${encodePart(documentId)}?key=${encodePart(apiKey)}"

internal fun certificateFingerprint(certificate: ByteArray): String =
    MessageDigest.getInstance("SHA-1").digest(certificate).joinToString("") { "%02X".format(it) }

internal fun wotdShareLink(wall: WotdWall): String? =
    if (wall.id.isEmpty()) null else "prism://share?id=${encodePart(wall.id)}&source=prism&url=${encodePart(wall.url)}"

internal fun firestoreStringField(document: String, name: String): String? = runCatching {
    JSONObject(document).optJSONObject("fields")?.optJSONObject(name)?.optString("stringValue", "")?.trim()?.ifEmpty { null }
}.getOrNull()

internal fun wotdWallIdFromPointer(document: String): String? = firestoreStringField(document, "wallId")

internal fun wotdWallFromDocument(id: String, document: String): WotdWall? =
    firestoreStringField(document, "wallpaper_url")?.let { WotdWall(id, it) }
