package com.hash.prism

import android.content.ContentResolver
import android.content.ClipData
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
import java.util.concurrent.FutureTask
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

internal class SharedInboxException(val code: String) : Exception(code)

/** A stuck provider cannot queue all later shares or create an unbounded number of threads. */
internal object SharedInboxWorkers {
    private fun pool(name: String) = ThreadPoolExecutor(0, 4, 60, TimeUnit.SECONDS, SynchronousQueue<Runnable>()) { work ->
        Thread(work, name).apply { isDaemon = true }
    }
    val copies = pool("prism-share-copy")
    private val closers = pool("prism-share-close")

    fun close(input: InputStream) {
        try {
            closers.execute { runCatching { input.close() } }
        } catch (_: RejectedExecutionException) {
            // Never block timeout delivery on a provider whose close operation also hangs.
        }
    }
}

/** The `prism://share-in` links that carry a share to Dart. Pure, so JVM tests cover it. */
internal object SharedInboxLinks {
    const val MAX_BYTES = 50L * 1024 * 1024
    const val MAX_TEXT = 2048
    private val idPattern = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
    private val sourcePattern = Regex("^[A-Za-z0-9._-]{1,128}$")
    private val imageExtensions = setOf("jpg", "png", "webp", "heic", "heif", "gif")

    fun isValidId(id: String) = idPattern.matches(id)

    /** Android may prefix a content authority with a user id, for example `0@com.example.provider`. */
    fun normalizedAuthority(authority: String): String = authority.substringAfterLast('@')

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
    fun copyLimited(input: InputStream, output: OutputStream, limit: Long = MAX_BYTES, canceled: () -> Boolean = { false }) {
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            if (Thread.currentThread().isInterrupted || canceled()) throw SharedInboxException("unreadable")
            val read = input.read(buffer)
            if (Thread.currentThread().isInterrupted || canceled()) throw SharedInboxException("unreadable")
            if (read < 0) break
            total += read
            if (total > limit) throw SharedInboxException("too-large")
            output.write(buffer, 0, read)
        }
        if (total == 0L) throw SharedInboxException("unreadable")
    }

    fun takeFile(folder: File, id: String): File {
        if (!isValidId(id)) throw SharedInboxException("invalid-id")
        val file = folder.listFiles()?.firstOrNull { it.nameWithoutExtension == id && it.extension != "part" }
            ?: throw SharedInboxException("missing")
        val code = when {
            file.extension !in imageExtensions || !file.isFile || file.canonicalFile != File(folder.canonicalFile, file.name) ||
                !file.canRead() || file.length() == 0L -> "unreadable"
            file.length() > MAX_BYTES -> "too-large"
            else -> null
        }
        if (code != null) {
            file.delete()
            throw SharedInboxException(code)
        }
        return file
    }

    fun sweep(folder: File, activeIds: Set<String> = emptySet(), now: Long = System.currentTimeMillis()) {
        folder.listFiles()?.forEach { file ->
            if (file.nameWithoutExtension !in activeIds &&
                (file.extension == "part" || now - file.lastModified() > TimeUnit.HOURS.toMillis(24))) file.delete()
        }
    }

    private fun sourceParam(source: String?) =
        if (source != null && sourcePattern.matches(source)) "&src=$source" else ""

    private fun encode(value: String) = URLEncoder.encode(value, "UTF-8").replace("+", "%20")
}

/** Cancellation also guards publication: a provider may return bytes after its Future was canceled. */
internal class SharedInboxCopy(private val folder: File, private val id: String, ext: String, open: () -> InputStream?) {
    private val part = File(folder, "$id.part")
    private val done = File(folder, "$id.$ext")
    @Volatile private var abandoned = false
    private var input: InputStream? = null
    private var completed = false
    val task = FutureTask<File> {
        try {
            val input = open() ?: throw SharedInboxException("unreadable")
            input.use { source ->
                val output = synchronized(this) {
                    if (abandoned) throw SharedInboxException("unreadable")
                    this.input = source
                    folder.mkdirs()
                    part.outputStream()
                }
                output.use { SharedInboxLinks.copyLimited(source, it, canceled = { abandoned }) }
            }
            synchronized(this) {
                if (abandoned || !part.renameTo(done)) throw SharedInboxException("unreadable")
                completed = true
            }
            done
        } finally {
            synchronized(this) { input = null }
            part.delete()
        }
    }

    fun start() {
        try {
            SharedInboxWorkers.copies.execute(task)
        } catch (_: RejectedExecutionException) {
            abandon()
        }
    }

    fun take(timeoutMillis: Long): File {
        try {
            task.get(timeoutMillis, TimeUnit.MILLISECONDS)
            return SharedInboxLinks.takeFile(folder, id)
        } catch (error: Exception) {
            abandon()
            if (error is InterruptedException) Thread.currentThread().interrupt()
            throw (if (error is ExecutionException) error.cause else error) as? SharedInboxException
                ?: SharedInboxException("unreadable")
        }
    }

    @Synchronized fun expire() {
        if (!completed) abandon()
    }

    @Synchronized private fun abandon() {
        abandoned = true
        task.cancel(true)
        part.delete()
        done.delete()
        input?.let(SharedInboxWorkers::close)
    }
}

/**
 * Copies a shared image into `filesDir/shared_inbox` off the main thread and gives Dart its path on `take`.
 * The copy can be slow for a cloud photo, so the app opens at once and Dart waits for the file.
 */
internal object SharedInbox {
    private const val TAKE_TIMEOUT_SECONDS = 30L
    private val waits = Executors.newCachedThreadPool()
    private val pending = ConcurrentHashMap<String, SharedInboxCopy>()
    private val deadlines = Executors.newSingleThreadScheduledExecutor()

    fun folder(context: Context) = File(context.filesDir, "shared_inbox")

    /**
     * The `prism://share-in` VIEW intent for an ACTION_SEND [intent], or null when it is not a share Prism takes.
     * Only `content:` streams from other apps are read, so a share cannot point Prism at its own private files.
     */
    fun linkIntent(context: Context, intent: Intent, source: String?): Intent? {
        sweep(context)
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
        return Intent(Intent.ACTION_VIEW, Uri.parse(link)).setPackage(context.packageName).apply {
            if (type.startsWith("image/")) {
                // MainActivity owns this grant after the transient share activity finishes.
                clipData = ClipData.newRawUri("shared-image", stream(intent))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
    }

    fun register(context: Context, channel: MethodChannel) {
        val appContext = context.applicationContext
        val main = Handler(Looper.getMainLooper())
        channel.setMethodCallHandler { call, result ->
            sweep(appContext)
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
        sweep(context)
        if (!SharedInboxLinks.isValidId(id)) throw SharedInboxException("invalid-id")
        val copy = pending[id]
        if (copy != null) {
            try {
                return copy.take(TimeUnit.SECONDS.toMillis(TAKE_TIMEOUT_SECONDS))
            } finally { pending.remove(id, copy) }
        }
        return SharedInboxLinks.takeFile(folder(context), id)
    }

    private fun startCopy(context: Context, uri: Uri, mimeType: String): String {
        val id = UUID.randomUUID().toString()
        val resolver = context.contentResolver
        val copy = SharedInboxCopy(folder(context), id, SharedInboxLinks.extensionFor(mimeType)) {
            resolver.openInputStream(uri)
        }
        pending[id] = copy
        copy.start()
        deadlines.schedule({
            copy.expire()
            pending.remove(id, copy)
        }, TAKE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        return id
    }

    private fun sweep(context: Context) = SharedInboxLinks.sweep(folder(context), pending.keys)

    private fun stream(intent: Intent): Uri? = if (Build.VERSION.SDK_INT >= 33) {
        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        @Suppress("DEPRECATION")
        intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
    }

    private fun isForeignContent(context: Context, uri: Uri): Boolean {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return false
        val authority = uri.authority ?: return false
        return SharedInboxLinks.normalizedAuthority(authority) !in ownAuthorities(context)
    }

    private fun ownAuthorities(context: Context): Set<String> {
        @Suppress("DEPRECATION")
        val providers = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PROVIDERS).providers
        return providers.orEmpty().flatMap { it.authority.orEmpty().split(';') }.toSet()
    }
}
