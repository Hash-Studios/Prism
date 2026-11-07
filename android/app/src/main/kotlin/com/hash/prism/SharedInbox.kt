package com.hash.prism

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.net.URLEncoder
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

internal class SharedInboxException(val code: String) : Exception(code)

/** The `prism://share-in` links that carry a share to Dart. Pure, so JVM tests cover it. */
internal object SharedInboxLinks {
    const val MAX_BYTES = 50L * 1024 * 1024
    const val MAX_TEXT = 2048
    private val idPattern = Regex("^[0-9a-f-]{36}$")
    private val sourcePattern = Regex("^[A-Za-z0-9._-]{1,128}$")

    fun isValidId(id: String) = idPattern.matches(id)

    fun extensionFor(mimeType: String?): String = when (mimeType?.lowercase()) {
        "image/png" -> "png"
        "image/webp" -> "webp"
        "image/heic" -> "heic"
        "image/heif" -> "heif"
        "image/gif" -> "gif"
        else -> "jpg"
    }

    fun imageLink(id: String, source: String?): String = "prism://share-in?id=$id${sourceParam(source)}"

    fun textLink(text: String, source: String?): String? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null
        var end = minOf(trimmed.length, MAX_TEXT)
        if (end < trimmed.length && Character.isHighSurrogate(trimmed[end - 1])) end--
        return "prism://share-in?text=${encode(trimmed.substring(0, end))}${sourceParam(source)}"
    }

    /** Copies at most [MAX_BYTES]. A longer stream throws `too-large`. */
    fun copyLimited(input: InputStream, output: OutputStream, limit: Long = MAX_BYTES) {
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            if (total > limit) throw SharedInboxException("too-large")
            output.write(buffer, 0, read)
        }
        if (total == 0L) throw SharedInboxException("unreadable")
    }

    private fun sourceParam(source: String?) =
        if (source != null && sourcePattern.matches(source)) "&src=$source" else ""

    private fun encode(value: String) = URLEncoder.encode(value, "UTF-8").replace("+", "%20")
}

/**
 * Copies a shared image into `filesDir/shared_inbox` off the main thread and gives Dart its path on `take`.
 * The copy can be slow for a cloud photo, so the app opens at once and Dart waits for the file.
 */
internal object SharedInbox {
    private const val CHANNEL = "prism/shared_inbox"
    private const val TAKE_TIMEOUT_SECONDS = 30L
    private val copies = Executors.newSingleThreadExecutor()
    private val waits = Executors.newCachedThreadPool()
    private val pending = ConcurrentHashMap<String, Future<File>>()

    fun folder(context: Context) = File(context.filesDir, "shared_inbox")

    /**
     * The `prism://share-in` VIEW intent for an ACTION_SEND [intent], or null when it is not a share Prism takes.
     * Only `content:` streams from other apps are read, so a share cannot point Prism at its own private files.
     */
    fun linkIntent(context: Context, intent: Intent, source: String?): Intent? {
        if (intent.action != Intent.ACTION_SEND) return null
        val type = intent.type?.lowercase() ?: return null
        val link = when {
            type.startsWith("image/") -> {
                val stream = stream(intent) ?: return null
                if (!isForeignContent(context, stream)) return null
                SharedInboxLinks.imageLink(startCopy(context, stream, type), source)
            }
            type == "text/plain" -> {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return null
                SharedInboxLinks.textLink(text, source) ?: return null
            }
            else -> return null
        }
        return Intent(Intent.ACTION_VIEW, Uri.parse(link)).setPackage(context.packageName)
    }

    fun register(context: Context, channel: MethodChannel) {
        val appContext = context.applicationContext
        val main = Handler(Looper.getMainLooper())
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "directory" -> result.success(folder(appContext).absolutePath)
                "take" -> {
                    val id = call.arguments as? String
                    if (id == null || !SharedInboxLinks.isValidId(id)) {
                        result.error("invalid-id", "The shared item id is not valid", null)
                    } else {
                        waits.execute {
                            val outcome = runCatching { take(appContext, id) }
                            main.post {
                                outcome.fold(
                                    { result.success(it.absolutePath) },
                                    { error -> result.error((error as? SharedInboxException)?.code ?: "unreadable", error.message, null) },
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Blocks until the copy for [id] ends. Call it off the main thread. */
    fun take(context: Context, id: String): File {
        val copy = pending[id]
        if (copy != null) {
            try {
                return copy.get(TAKE_TIMEOUT_SECONDS, TimeUnit.SECONDS).also { pending.remove(id) }
            } catch (error: ExecutionException) {
                pending.remove(id)
                throw error.cause as? SharedInboxException ?: SharedInboxException("unreadable")
            } catch (_: TimeoutException) {
                throw SharedInboxException("unreadable")
            }
        }
        return folder(context).listFiles()?.firstOrNull { it.nameWithoutExtension == id && it.extension != "part" }
            ?: throw SharedInboxException("missing")
    }

    private fun startCopy(context: Context, uri: Uri, mimeType: String): String {
        val id = UUID.randomUUID().toString()
        val resolver = context.contentResolver
        val folder = folder(context)
        val name = "$id.${SharedInboxLinks.extensionFor(mimeType)}"
        // Open the stream now, while this activity still holds the read grant. The copy can outlive it.
        val input = runCatching { resolver.openInputStream(uri) }.getOrNull()
        pending[id] = copies.submit<File> { copy(input, folder, id, name) }
        return id
    }

    private fun copy(input: InputStream?, folder: File, id: String, name: String): File {
        input ?: throw SharedInboxException("unreadable")
        val part = File(folder, "$id.part")
        try {
            input.use { source ->
                folder.mkdirs()
                part.outputStream().use { SharedInboxLinks.copyLimited(source, it) }
            }
            val done = File(folder, name)
            if (!part.renameTo(done)) throw SharedInboxException("unreadable")
            return done
        } catch (error: SharedInboxException) {
            part.delete()
            throw error
        } catch (_: Exception) {
            part.delete()
            throw SharedInboxException("unreadable")
        }
    }

    private fun stream(intent: Intent): Uri? = if (Build.VERSION.SDK_INT >= 33) {
        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        @Suppress("DEPRECATION")
        intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
    }

    private fun isForeignContent(context: Context, uri: Uri): Boolean {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return false
        val authority = uri.authority ?: return false
        return authority !in ownAuthorities(context)
    }

    private fun ownAuthorities(context: Context): Set<String> {
        @Suppress("DEPRECATION")
        val providers = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PROVIDERS).providers
        return providers.orEmpty().flatMap { it.authority.orEmpty().split(';') }.toSet()
    }
}
