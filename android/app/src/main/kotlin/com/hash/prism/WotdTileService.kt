package com.hash.prism

import android.app.WallpaperManager
import android.content.SharedPreferences
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import android.widget.Toast
import androidx.annotation.RequiresApi
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Quick Settings tile: "Wall of the Day"
 *
 * Applies today's curated Wall of the Day wallpaper. The Flutter app caches
 * the current WOTD URL in SharedPreferences whenever [WotdBloc] emits a
 * success state (via [QuickTileConfigService.pushWotdUrl]).
 *
 * Because the URL is pre-cached, this tile works instantly without needing
 * a Firestore call at tap time.
 *
 * Requires API 24+ (Android 7.0) for TileService.
 */
@RequiresApi(api = Build.VERSION_CODES.N)
class WotdTileService : TileService() {

    companion object {
        private const val TAG = "Prism::WotdTile"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        // SharedPreferences keys — must match PersistenceKeys in Dart
        private const val KEY_WOTD_URL = "flutter.quick_tile.wotd.url"
        private const val KEY_WOTD_TARGET = "flutter.quick_tile.wotd.target"

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
                applyWotdWallpaper()
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected error applying WOTD wallpaper", e)
                showToast("Could not apply Wall of the Day")
            } finally {
                qsTile?.apply {
                    state = Tile.STATE_INACTIVE
                    updateTile()
                }
            }
        }
    }

    private fun applyWotdWallpaper() {
        val prefs: SharedPreferences = applicationContext
            .getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        val wotdUrl = prefs.getString(KEY_WOTD_URL, null)?.trim()
        val target = prefs.getString(KEY_WOTD_TARGET, "both")?.trim() ?: "both"

        if (wotdUrl.isNullOrEmpty()) {
            showToast("Open Prism to load today's Wall of the Day first")
            return
        }

        Log.d(TAG, "Applying WOTD wallpaper: url=$wotdUrl target=$target")
        applyWallpaperFromUrl(wotdUrl, target)
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
                Log.e(TAG, "HTTP ${connection.responseCode} fetching WOTD image")
                showToast("Could not download Wall of the Day")
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
            Log.d(TAG, "WOTD wallpaper applied (target=$target)")
        } catch (e: IOException) {
            Log.e(TAG, "IO error applying WOTD wallpaper", e)
            showToast("Failed to apply Wall of the Day")
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
