package com.hash.prism

import android.app.WallpaperManager
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import android.widget.Toast
import java.io.File
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.Executors

internal enum class TileWallpaperTarget(val flags: Int) {
    HOME(WallpaperManager.FLAG_SYSTEM), LOCK(WallpaperManager.FLAG_LOCK), BOTH(WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK);

    companion object {
        fun parse(raw: String?): TileWallpaperTarget = when (raw?.trim()) {
            "home" -> HOME
            "lock" -> LOCK
            "both", null -> BOTH
            else -> throw IllegalArgumentException("Invalid wallpaper target; open Prism and save tile settings")
        }
    }
}

internal class WallpaperUnavailableException : IOException()

internal fun tileErrorMessage(error: Throwable): Int = when (error) {
    is UnknownHostException -> R.string.tile_error_offline
    is SocketTimeoutException -> R.string.tile_error_timeout
    is WallpaperUnavailableException -> R.string.tile_error_unavailable
    is IOException -> R.string.tile_error_download
    is IllegalStateException, is IllegalArgumentException -> R.string.tile_error_setup
    else -> R.string.tile_error_generic
}

internal abstract class WallpaperTileService : TileService() {
    internal data class Wallpaper(val url: String, val target: TileWallpaperTarget)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    @Volatile private var destroyed = false
    private var applying = false

    internal abstract fun wallpaper(prefs: SharedPreferences): Wallpaper

    internal open fun isConfigured(prefs: SharedPreferences): Boolean = true

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (destroyed || applying) return
        if (isLocked) unlockAndRun { applyWallpaper() } else applyWallpaper()
    }

    private fun applyWallpaper() {
        if (destroyed || applying) return
        applying = true
        updateTile()
        executor.execute {
            var file: File? = null
            try {
                val wallpaper = wallpaper(applicationContext.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE))
                file = File.createTempFile("prism-tile-", ".tmp", cacheDir)
                PrismImageTransfer.download(wallpaper.url, file)
                PrismImageValidation.mime(file)
                val manager = WallpaperManager.getInstance(applicationContext)
                if (!manager.isWallpaperSupported || !manager.isSetWallpaperAllowed) throw WallpaperUnavailableException()
                file.inputStream().use { manager.setStream(it, null, false, wallpaper.target.flags) }
                mainHandler.post { if (!destroyed) Toast.makeText(applicationContext, R.string.tile_wallpaper_updated, Toast.LENGTH_SHORT).show() }
            } catch (error: Throwable) {
                Log.w("PrismTile", "Could not apply wallpaper", error)
                mainHandler.post { if (!destroyed) Toast.makeText(applicationContext, tileErrorMessage(error), Toast.LENGTH_SHORT).show() }
            } finally {
                file?.delete()
                mainHandler.post { applying = false; if (!destroyed) updateTile() }
            }
        }
    }

    private fun updateTile() {
        val ready = isConfigured(applicationContext.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE))
        qsTile?.apply {
            state = if (!ready) Tile.STATE_UNAVAILABLE else if (applying) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) subtitle = if (ready) null else "Open Prism to set up"
            updateTile()
        }
    }

    override fun onDestroy() {
        destroyed = true
        executor.shutdown()
        super.onDestroy()
    }
}
