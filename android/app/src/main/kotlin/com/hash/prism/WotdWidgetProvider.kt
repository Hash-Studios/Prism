package com.hash.prism

import android.app.PendingIntent
import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.Toast
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal fun widgetSampleSize(width: Int, height: Int, maxPixels: Long = 1_000_000L): Int {
    var sample = 1
    while ((width.toLong() / sample) * (height.toLong() / sample) > maxPixels) sample *= 2
    return sample
}

internal class WotdWidgetProvider : AppWidgetProvider() {
    private class Shown(val wall: WotdWall, val bitmap: Bitmap)

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SET_WALLPAPER) setWallpaper(context) else super.onReceive(context, intent)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val pending = goAsync()
        val app = context.applicationContext
        val deadline = monotonicMillis() + UPDATE_BUDGET_MS
        executor.execute {
            try {
                synchronized(updateLock) {
                    val shown = loadShown(app, deadline)
                    appWidgetIds.forEach { manager.updateAppWidget(it, views(app, shown)) }
                }
            } catch (error: Throwable) {
                Log.w(TAG, "Could not update widget", error)
            } finally {
                pending.finish()
            }
        }
    }

    private fun setWallpaper(context: Context) {
        val pending = goAsync()
        val app = context.applicationContext
        if (!setting.compareAndSet(false, true)) {
            pending.finish()
            return
        }
        executor.execute {
            try {
                val message = try {
                    applyWallpaper(app)
                    R.string.wotd_widget_set_done
                } catch (error: Throwable) {
                    Log.w(TAG, "Could not set wallpaper", error)
                    R.string.wotd_widget_set_failed
                }
                mainHandler.post { Toast.makeText(app, message, Toast.LENGTH_SHORT).show() }
            } finally {
                setting.set(false)
                pending.finish()
            }
        }
    }

    private fun applyWallpaper(context: Context) {
        val manager = WallpaperManager.getInstance(context)
        if (!manager.isWallpaperSupported || !manager.isSetWallpaperAllowed) throw WallpaperUnavailableException()
        val url = attempt("fetch for wallpaper") { fetchWall(context, monotonicMillis() + SET_FETCH_BUDGET_MS) }?.url
            ?: widgetPrefs(context).getString(PREF_URL, null)?.takeIf { it.isNotBlank() }
            ?: storedWall(context)?.url
            ?: throw IllegalStateException("No wallpaper to set")
        val file = File.createTempFile("prism-widget-wall-", ".tmp", context.cacheDir)
        try {
            PrismImageTransfer.download(url, file)
            PrismImageValidation.mime(file)
            val bitmap = decodeForScreen(context, file)
            try {
                manager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_SYSTEM)
            } finally {
                bitmap.recycle()
            }
        } finally {
            file.delete()
        }
    }

    private fun decodeForScreen(context: Context, file: File): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw IOException("Invalid image")
        val metrics = context.resources.displayMetrics
        val sample = wallpaperSampleSize(
            bounds.outWidth,
            bounds.outHeight,
            minOf(metrics.widthPixels, metrics.heightPixels),
            maxOf(metrics.widthPixels, metrics.heightPixels),
        )
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeFile(file.path, options) ?: throw IOException("Could not decode image")
    }

    private fun loadShown(context: Context, deadline: Long): Shown? {
        val prefs = widgetPrefs(context)
        val candidates = listOfNotNull(attempt("fetch wall") { fetchWall(context, deadline) }, storedWall(context)).distinctBy { it.url }
        for (wall in candidates) {
            val bitmap = cachedBitmap(context, prefs, wall) ?: attempt("download image") { downloadBitmap(context, wall.url, deadline) }
                ?.also { attempt("save cache") { saveCache(context, prefs, wall, it) } }
            if (bitmap != null) return Shown(wall, bitmap)
        }
        val lastUrl = prefs.getString(PREF_URL, null) ?: return null
        val last = WotdWall(prefs.getString(PREF_ID, null).orEmpty(), lastUrl)
        val bitmap = BitmapFactory.decodeFile(cacheFile(context).path) ?: return null
        return Shown(last, bitmap)
    }

    private fun fetchWall(context: Context, deadline: Long): WotdWall? {
        val projectId = stringResource(context, "project_id") ?: return null
        val apiKey = stringResource(context, "google_api_key") ?: return null
        val headers = mapOf("X-Android-Package" to context.packageName) + signingHeader(context)
        val pointer = httpText(firestoreDocumentUrl(projectId, "wall_of_the_day", "current", apiKey), headers, deadline)
        val wallId = wotdWallIdFromPointer(pointer) ?: return null
        return wotdWallFromDocument(wallId, httpText(firestoreDocumentUrl(projectId, "walls", wallId, apiKey), headers, deadline))
    }

    private fun stringResource(context: Context, name: String): String? {
        val id = context.resources.getIdentifier(name, "string", context.packageName)
        return if (id == 0) null else context.getString(id).trim().ifEmpty { null }
    }

    private fun signingHeader(context: Context): Map<String, String> {
        val fingerprint = signingFingerprint ?: attempt("signing certificate") { signingCertificate(context)?.let(::certificateFingerprint) }
            ?.also { signingFingerprint = it }
        return if (fingerprint == null) emptyMap() else mapOf("X-Android-Cert" to fingerprint)
    }

    @Suppress("DEPRECATION")
    private fun signingCertificate(context: Context): ByteArray? {
        val packageManager = context.packageManager
        val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            packageManager.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES).signatures?.firstOrNull()
        }
        return signature?.toByteArray()
    }

    private fun storedWall(context: Context): WotdWall? {
        val url = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.quick_tile.wotd.url", null)?.trim()
        return if (url.isNullOrEmpty()) null else WotdWall("", url)
    }

    private fun httpText(link: String, headers: Map<String, String>, deadline: Long): String {
        val connection = openConnection(link, headers, deadline)
        try {
            val output = ByteArrayOutputStream()
            connection.inputStream.use { copyWithin(it, output, MAX_JSON_BYTES, deadline) }
            return String(output.toByteArray(), Charsets.UTF_8)
        } finally {
            connection.disconnect()
        }
    }

    private fun openConnection(link: String, headers: Map<String, String>, deadline: Long): HttpURLConnection {
        var url = URL(link)
        var requestHeaders = headers
        repeat(MAX_REDIRECTS + 1) { redirects ->
            require(url.protocol == "https" && url.host.isNotBlank() && url.userInfo == null) { "Invalid widget URL" }
            val connection = url.openConnection() as HttpURLConnection
            var returned = false
            try {
                val timeout = timeoutWithin(CONNECTION_TIMEOUT_MS, deadline, monotonicMillis())
                connection.connectTimeout = timeout
                connection.readTimeout = timeout
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("User-Agent", "Prism Android")
                requestHeaders.forEach(connection::setRequestProperty)
                val code = connection.responseCode
                if (code == HttpURLConnection.HTTP_OK) {
                    returned = true
                    return connection
                }
                if (code !in REDIRECT_CODES) throw IOException("HTTP $code")
                if (redirects == MAX_REDIRECTS) throw IOException("Too many redirects")
                val next = URL(url, connection.getHeaderField("Location") ?: throw IOException("Missing redirect location"))
                if (url.host != next.host || url.port != next.port) requestHeaders = emptyMap()
                url = next
            } finally {
                if (!returned) connection.disconnect()
            }
        }
        throw IOException("Too many redirects")
    }

    private fun downloadBitmap(context: Context, url: String, deadline: Long): Bitmap? {
        val file = File.createTempFile("prism-widget-", ".tmp", context.cacheDir)
        try {
            val connection = openConnection(url, emptyMap(), deadline)
            try {
                if (connection.contentLengthLong > PrismImageTransfer.MAX_IMAGE_BYTES) throw IOException("Image exceeds 100 MiB")
                connection.inputStream.use { input ->
                    file.outputStream().use { copyWithin(input, it, PrismImageTransfer.MAX_IMAGE_BYTES, deadline) }
                }
            } finally {
                connection.disconnect()
            }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            val options = BitmapFactory.Options().apply { inSampleSize = widgetSampleSize(bounds.outWidth, bounds.outHeight) }
            return BitmapFactory.decodeFile(file.path, options)
        } finally {
            file.delete()
        }
    }

    private fun cacheFile(context: Context): File = File(context.cacheDir, "wotd_widget_last.jpg")

    private fun cachedBitmap(context: Context, prefs: SharedPreferences, wall: WotdWall): Bitmap? =
        if (prefs.getString(PREF_KEY, null) == wall.key) BitmapFactory.decodeFile(cacheFile(context).path) else null

    private fun saveCache(context: Context, prefs: SharedPreferences, wall: WotdWall, bitmap: Bitmap) {
        cacheFile(context).outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        prefs.edit().putString(PREF_KEY, wall.key).putString(PREF_ID, wall.id).putString(PREF_URL, wall.url).apply()
    }

    private fun widgetPrefs(context: Context): SharedPreferences = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)

    private fun <T> attempt(label: String, block: () -> T): T? = try {
        block()
    } catch (error: Throwable) {
        Log.w(TAG, "Widget step failed: $label", error)
        null
    }

    private fun views(context: Context, shown: Shown?): RemoteViews = RemoteViews(context.packageName, R.layout.wotd_widget).apply {
        if (shown != null) setImageViewBitmap(R.id.wotd_image, shown.bitmap)
        val withImage = if (shown != null) View.VISIBLE else View.GONE
        val empty = if (shown != null) View.GONE else View.VISIBLE
        setViewVisibility(R.id.wotd_image, withImage)
        setViewVisibility(R.id.wotd_scrim, withImage)
        setViewVisibility(R.id.wotd_label, withImage)
        setViewVisibility(R.id.wotd_set, withImage)
        setViewVisibility(R.id.wotd_empty, empty)
        val launch = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        shown?.wall?.let(::wotdShareLink)?.let { link ->
            launch.action = Intent.ACTION_VIEW
            launch.data = Uri.parse(link)
        }
        setOnClickPendingIntent(R.id.wotd_root, PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        val set = Intent(context, WotdWidgetProvider::class.java).setAction(ACTION_SET_WALLPAPER)
        setOnClickPendingIntent(R.id.wotd_set, PendingIntent.getBroadcast(context, 1, set, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
    }

    companion object {
        private const val TAG = "PrismWidget"
        private const val ACTION_SET_WALLPAPER = "com.hash.prism.action.WOTD_SET_WALLPAPER"
        private const val WIDGET_PREFS = "prism_wotd_widget"
        private const val PREF_KEY = "key"
        private const val PREF_ID = "id"
        private const val PREF_URL = "url"
        private const val UPDATE_BUDGET_MS = 8_500L
        private const val SET_FETCH_BUDGET_MS = 5_000L
        private const val CONNECTION_TIMEOUT_MS = 4_000
        private const val MAX_JSON_BYTES = 256L * 1024
        private const val MAX_REDIRECTS = 3
        private val REDIRECT_CODES = setOf(301, 302, 303, 307, 308)
        private val executor = Executors.newFixedThreadPool(2)
        private val updateLock = Any()
        private val setting = AtomicBoolean(false)
        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile private var signingFingerprint: String? = null

        fun refresh(context: Context) {
            val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, WotdWidgetProvider::class.java))
            if (ids.isEmpty()) return
            context.sendBroadcast(
                Intent(context, WotdWidgetProvider::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }
}
