package com.hash.prism

import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL

/** A transfer failure that a second request cannot fix. */
internal class PermanentTransferException(message: String) : IOException(message)

internal object PrismImageTransfer {
    // ponytail: wallpaper transfers are capped at 100 MiB; raise this if supported image providers need more.
    const val MAX_IMAGE_BYTES = 100L * 1024 * 1024
    private const val MAX_REDIRECTS = 5
    private const val HTTPS = "https"
    private val redirectCodes = setOf(301, 302, 303, 307, 308)

    fun validateFilename(name: String): String = validateLeaf(name, 200)

    fun validateStoredFilename(name: String): String = validateLeaf(name, 255)

    private fun validateLeaf(name: String, maxBytes: Int): String {
        require(name.isNotBlank() && name != "." && name != ".." && name.toByteArray(Charsets.UTF_8).size <= maxBytes) { "Invalid filename" }
        require(name.none { it == '/' || it == '\\' || it.isISOControl() }) { "Invalid filename" }
        return name
    }

    fun openConnection(link: String, headers: Map<String, String> = emptyMap()): HttpURLConnection {
        var url = URL(link)
        var requestHeaders = headers
        repeat(MAX_REDIRECTS + 1) { redirects ->
            require(url.protocol == "http" || url.protocol == HTTPS) { "Unsupported URL protocol" }
            require(url.host.isNotBlank() && url.userInfo == null) { "Invalid download URL" }
            val connection = url.openConnection() as HttpURLConnection
            var returned = false
            try {
                connection.connectTimeout = 10_000
                connection.readTimeout = 20_000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("User-Agent", "Prism Android")
                requestHeaders.forEach(connection::setRequestProperty)
                val code = connection.responseCode
                if (code !in redirectCodes) {
                    if (code in 400..499) throw PermanentTransferException("HTTP $code")
                    if (code != HttpURLConnection.HTTP_OK) throw IOException("HTTP $code")
                    returned = true
                    return connection
                }
                if (redirects == MAX_REDIRECTS) throw PermanentTransferException("Too many download redirects")
                val next = URL(url, connection.getHeaderField("Location") ?: throw PermanentTransferException("Missing redirect location"))
                if (url.protocol == HTTPS && next.protocol != HTTPS) throw PermanentTransferException("Insecure download redirect")
                if (url.host != next.host || url.port != next.port || url.protocol != next.protocol) requestHeaders = emptyMap()
                url = next
            } finally { if (!returned) connection.disconnect() }
        }
        throw PermanentTransferException("Too many download redirects")
    }

    /** Tries once more after a dropped, stalled or server-failed transfer (#547). */
    fun download(link: String, file: File) {
        try {
            downloadOnce(link, file)
        } catch (error: IOException) {
            if (error is PermanentTransferException || Thread.currentThread().isInterrupted) throw error
            try {
                downloadOnce(link, file)
            } catch (retryError: IOException) {
                retryError.addSuppressed(error)
                throw retryError
            }
        }
    }

    private fun downloadOnce(link: String, file: File) {
        val connection = openConnection(link)
        try {
            val expected = connection.contentLengthLong
            if (expected > MAX_IMAGE_BYTES) throw PermanentTransferException("Image exceeds 100 MiB")
            val written = connection.inputStream.use { input -> file.outputStream().use { copy(input, it) } }
            val encoding = connection.contentEncoding
            val unencoded = encoding.isNullOrBlank() || encoding.equals("identity", true)
            if (unencoded && expected >= 0 && written != expected) {
                throw IOException("Incomplete image response")
            }
        } finally {
            connection.disconnect()
        }
    }

    fun copy(input: InputStream, output: OutputStream, maxBytes: Long = MAX_IMAGE_BYTES): Long {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var bytes = 0L
        while (true) {
            if (Thread.currentThread().isInterrupted) throw PermanentTransferException("Transfer cancelled")
            val count = input.read(buffer)
            if (count < 0) break
            bytes += count
            if (bytes > maxBytes) throw PermanentTransferException("Image exceeds size limit")
            output.write(buffer, 0, count)
        }
        if (bytes == 0L) throw IOException("Image is empty")
        return bytes
    }
}
