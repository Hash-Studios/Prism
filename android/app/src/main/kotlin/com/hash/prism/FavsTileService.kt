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
 * Quick Settings tile: "Random from Favourites"
 *
 * Picks a random wallpaper from the user's saved favourites and applies it.
 * The Flutter app keeps a JSON-encoded list of full-resolution wallpaper URLs
 * in SharedPreferences (written by [QuickTileConfigService.pushFavWallUrls]
 * whenever [FavouriteWallsBloc] emits a success state).
 *
 * Requires API 24+ (Android 7.0) for TileService.
 */
@RequiresApi(api = Build.VERSION_CODES.N)
class FavsTileService : TileService() {

    companion object {
        private const val TAG = "Prism::FavsTile"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        // SharedPreferences keys — must match PersistenceKeys in Dart
        private const val KEY_FAVS_URLS = "flutter.quick_tile.favs.wall_urls"
        private const val KEY_FAVS_TARGET = "flutter.quick_tile.favs.target"

        // Wallpaper targets
        private const val TARGET_HOME = "home"
        private const val TARGET_LOCK = "lock"

        private const val CONNECT_TIMEOUT_MS = 10_000
        private const val READ_TIMEOUT_MS = 20_000
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
                applyRandomFavourite()
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected error applying favourite wallpaper", e)
                showToast("Could not apply favourite wallpaper")
            } finally {
                qsTile?.apply {
                    state = Tile.STATE_INACTIVE
                    updateTile()
                }
            }
        }
    }

    private fun applyRandomFavourite() {
        val prefs: SharedPreferences = applicationContext
            .getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        val urlsJson = prefs.getString(KEY_FAVS_URLS, null)
        val target = prefs.getString(KEY_FAVS_TARGET, "both")?.trim() ?: "both"

        if (urlsJson.isNullOrEmpty()) {
            showToast("No favourites found — open Prism and save some wallpapers first")
            return
        }

        val urls: List<String> = try {
            val arr = JSONArray(urlsJson)
            (0 until arr.length()).map { arr.getString(it) }.filter { it.isNotBlank() }
        } catch (e: JSONException) {
            Log.e(TAG, "Failed to parse favourite URLs JSON", e)
            emptyList()
        }

        if (urls.isEmpty()) {
            showToast("No favourites found — open Prism and save some wallpapers first")
            return
        }

        val wallpaperUrl = urls[(Math.random() * urls.size).toInt()]
        Log.d(TAG, "Applying favourite wallpaper: url=$wallpaperUrl target=$target")
        applyWallpaperFromUrl(wallpaperUrl, target)
    }

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
                Log.e(TAG, "HTTP ${connection.responseCode} fetching favourite image")
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
            Log.d(TAG, "Favourite wallpaper applied (target=$target)")
        } catch (e: IOException) {
            Log.e(TAG, "IO error applying favourite wallpaper", e)
            showToast("Failed to apply wallpaper")
        } finally {
            inputStream?.close()
            connection?.disconnect()
        }
    }

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
