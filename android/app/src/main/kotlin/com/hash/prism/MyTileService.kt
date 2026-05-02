package com.hash.prism

import android.app.WallpaperManager
import android.content.SharedPreferences
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import android.widget.Toast
import androidx.annotation.RequiresApi
import org.json.JSONArray
import org.json.JSONException
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Quick Settings tile: "Random from Category"
 *
 * Reads the user's configured category + wallpaper source + target from
 * SharedPreferences (written by the Flutter app via [QuickTileConfigService])
 * then fetches a random wallpaper URL from the Pexels or Wallhaven API and
 * applies it asynchronously using [WallpaperManager].
 *
 * All network I/O is off the main thread via a single-threaded executor.
 * Requires API 24+ (Android 7.0) for TileService.
 */
@RequiresApi(api = Build.VERSION_CODES.N)
class MyTileService : TileService() {

    companion object {
        private const val TAG = "Prism::CategoryTile"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        // SharedPreferences keys — must match PersistenceKeys in Dart
        private const val KEY_CATEGORY_NAME = "flutter.quick_tile.category.name"
        private const val KEY_CATEGORY_SOURCE = "flutter.quick_tile.category.source"
        private const val KEY_CATEGORY_TARGET = "flutter.quick_tile.category.target"

        // Wallpaper sources
        private const val SOURCE_PEXELS = "pexels"
        private const val SOURCE_WALLHAVEN = "wallhaven"

        // Wallpaper targets
        private const val TARGET_HOME = "home"
        private const val TARGET_LOCK = "lock"
        // anything else → both

        private const val CONNECT_TIMEOUT_MS = 10_000
        private const val READ_TIMEOUT_MS = 15_000
    }

    private val executor = Executors.newSingleThreadExecutor()

    override fun onTileAdded() {
        super.onTileAdded()
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()

        qsTile?.apply {
            state = Tile.STATE_ACTIVE
            updateTile()
        }

        executor.execute {
            try {
                applyRandomWallpaper()
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected error applying wallpaper", e)
                showToast("Could not apply wallpaper")
            } finally {
                qsTile?.apply {
                    state = Tile.STATE_INACTIVE
                    updateTile()
                }
            }
        }
    }

    private fun applyRandomWallpaper() {
        val prefs: SharedPreferences = applicationContext
            .getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        val categoryName = prefs.getString(KEY_CATEGORY_NAME, null)?.trim()
        val source = prefs.getString(KEY_CATEGORY_SOURCE, SOURCE_PEXELS)?.trim() ?: SOURCE_PEXELS
        val target = prefs.getString(KEY_CATEGORY_TARGET, "both")?.trim() ?: "both"

        if (categoryName.isNullOrEmpty()) {
            showToast("Open Prism and configure the Quick Tile first")
            return
        }

        Log.d(TAG, "Fetching random wallpaper: category=$categoryName source=$source target=$target")

        val wallpaperUrl = when (source) {
            SOURCE_WALLHAVEN -> fetchRandomWallhavenUrl(categoryName)
            else -> fetchRandomPexelsUrl(categoryName)
        }

        if (wallpaperUrl.isNullOrEmpty()) {
            showToast("No wallpaper found — check your connection")
            return
        }

        Log.d(TAG, "Applying wallpaper from URL: $wallpaperUrl")
        applyWallpaperFromUrl(wallpaperUrl, target)
    }

    // ── Pexels ────────────────────────────────────────────────────────────────

    private fun fetchRandomPexelsUrl(query: String): String? {
        val apiKey = BuildConfig.PEXELS_API_KEY
        if (apiKey.isBlank()) {
            Log.w(TAG, "PEXELS_API_KEY is not set in BuildConfig")
            return null
        }

        val encodedQuery = java.net.URLEncoder.encode(query, "UTF-8")
        val apiUrl = "https://api.pexels.com/v1/search?query=$encodedQuery&per_page=30&orientation=portrait"

        val json = fetchJsonString(apiUrl, mapOf("Authorization" to apiKey)) ?: return null

        return try {
            val root = org.json.JSONObject(json)
            val photos = root.getJSONArray("photos")
            if (photos.length() == 0) return null
            val idx = (Math.random() * photos.length()).toInt()
            val photo = photos.getJSONObject(idx)
            val src = photo.getJSONObject("src")
            // Use the "original" size for full-resolution wallpaper
            src.getString("original")
        } catch (e: JSONException) {
            Log.e(TAG, "Failed to parse Pexels response", e)
            null
        }
    }

    // ── Wallhaven ─────────────────────────────────────────────────────────────

    private fun fetchRandomWallhavenUrl(query: String): String? {
        val encodedQuery = java.net.URLEncoder.encode(query, "UTF-8")
        // categories=111 (general+anime+people), purity=100 (SFW), sorting=random
        val apiUrl = "https://wallhaven.cc/api/v1/search?q=$encodedQuery" +
                "&categories=111&purity=100&sorting=random&per_page=24"

        val json = fetchJsonString(apiUrl, emptyMap()) ?: return null

        return try {
            val root = org.json.JSONObject(json)
            val data = root.getJSONArray("data")
            if (data.length() == 0) return null
            val idx = (Math.random() * data.length()).toInt()
            data.getJSONObject(idx).getString("path")
        } catch (e: JSONException) {
            Log.e(TAG, "Failed to parse Wallhaven response", e)
            null
        }
    }

    // ── Wallpaper application ─────────────────────────────────────────────────

    private fun applyWallpaperFromUrl(urlString: String, target: String) {
        var connection: HttpURLConnection? = null
        var inputStream: InputStream? = null
        try {
            val url = URL(urlString)
            connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                setRequestProperty("User-Agent", "Prism/1.0 Android")
                connect()
            }
            if (connection.responseCode !in 200..299) {
                Log.e(TAG, "HTTP ${connection.responseCode} fetching wallpaper image")
                showToast("Could not download wallpaper")
                return
            }

            inputStream = connection.inputStream
            val wallpaperManager = WallpaperManager.getInstance(applicationContext)

            val flags = when (target) {
                TARGET_HOME -> WallpaperManager.FLAG_SYSTEM
                TARGET_LOCK -> WallpaperManager.FLAG_LOCK
                else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
            }

            wallpaperManager.setStream(inputStream, null, false, flags)
            Log.d(TAG, "Wallpaper applied successfully (target=$target)")
        } catch (e: IOException) {
            Log.e(TAG, "IO error applying wallpaper", e)
            showToast("Failed to apply wallpaper")
        } finally {
            inputStream?.close()
            connection?.disconnect()
        }
    }

    // ── HTTP helper ───────────────────────────────────────────────────────────

    private fun fetchJsonString(urlString: String, headers: Map<String, String>): String? {
        var connection: HttpURLConnection? = null
        return try {
            val url = URL(urlString)
            connection = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                setRequestProperty("Accept", "application/json")
                headers.forEach { (k, v) -> setRequestProperty(k, v) }
                connect()
            }
            if (connection.responseCode !in 200..299) {
                Log.e(TAG, "HTTP ${connection.responseCode} for $urlString")
                return null
            }
            connection.inputStream.bufferedReader().use { it.readText() }
        } catch (e: IOException) {
            Log.e(TAG, "Network error fetching $urlString", e)
            null
        } finally {
            connection?.disconnect()
        }
    }

    // ── Utility ───────────────────────────────────────────────────────────────

    private fun showToast(message: String) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }
}
