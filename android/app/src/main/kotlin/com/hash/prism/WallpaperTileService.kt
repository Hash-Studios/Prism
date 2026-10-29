package com.hash.prism

import android.app.PendingIntent
import android.app.WallpaperManager
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.net.Uri
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

internal fun tileConfigured(isConfigured: () -> Boolean): Boolean = try {
    isConfigured()
} catch (_: ClassCastException) {
    false
}

internal fun readPreferenceString(read: () -> String?): String? = try {
    read()
} catch (_: ClassCastException) {
    null
}

internal fun deferredTileAction(
    resolveLink: () -> String?,
    openApp: (String) -> Unit,
    applyWallpaper: () -> Unit,
): () -> Unit = { resolveLink()?.let(openApp) ?: applyWallpaper() }

internal abstract class WallpaperTileService : TileService() {
    internal data class Wallpaper(val url: String, val target: TileWallpaperTarget)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    @Volatile private var destroyed = false
    private var applying = false

    internal abstract fun wallpaper(prefs: SharedPreferences): Wallpaper

    internal open fun isConfigured(prefs: SharedPreferences): Boolean = true

    /** A Prism link to open instead of setting a wallpaper, when the tile has nothing it can set. */
    internal open fun appLink(prefs: SharedPreferences): String? = null

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (destroyed || applying) return
        val action = deferredTileAction(
            resolveLink = {
                appLink(applicationContext.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE))
            },
            openApp = ::openApp,
            applyWallpaper = ::applyWallpaper,
        )
        if (isLocked) unlockAndRun(action) else action()
    }

    private fun openApp(link: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link))
            .setPackage(packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun applyWallpaper() {
        if (destroyed || applying) return
        applying = true
        updateTile()
        executor.execute {
            var file: File? = null
            var temporaryFile = false
            try {
                val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                val wallpaper = wallpaper(prefs)
                file = OfflineTileAssets.retainedFile(
                    wallpaper.url,
                    readPreferenceString { prefs.getString(OfflineTileAssets.PATHS_PREFERENCE, null) },
                    listOf(
                        File(filesDir, "prism/offline/assets/assets"),
                        File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Prism/Downloads"),
                        File(Environment.getExternalStorageDirectory(), "Prism/Downloads"),
                    ),
                )
                if (file == null) {
                    file = File.createTempFile("prism-tile-", ".tmp", cacheDir)
                    temporaryFile = true
                    PrismImageTransfer.download(wallpaper.url, file)
                    PrismImageValidation.mime(file)
                }
                val manager = WallpaperManager.getInstance(applicationContext)
                if (!manager.isWallpaperSupported || !manager.isSetWallpaperAllowed) throw WallpaperUnavailableException()
                checkNotNull(file).inputStream().use { manager.setStream(it, null, false, wallpaper.target.flags) }
                mainHandler.post { if (!destroyed) Toast.makeText(applicationContext, R.string.tile_wallpaper_updated, Toast.LENGTH_SHORT).show() }
            } catch (error: Throwable) {
                Log.w("PrismTile", "Could not apply wallpaper", error)
                mainHandler.post { if (!destroyed) Toast.makeText(applicationContext, tileErrorMessage(error), Toast.LENGTH_SHORT).show() }
            } finally {
                if (temporaryFile) file?.delete()
                mainHandler.post { applying = false; if (!destroyed) updateTile() }
            }
        }
    }

    private fun updateTile() {
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val ready = tileConfigured { isConfigured(prefs) }
        qsTile?.apply {
            state = if (!ready) Tile.STATE_UNAVAILABLE else if (applying) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                subtitle = if (ready) null else applicationContext.getString(R.string.tile_setup_subtitle)
            }
            updateTile()
        }
    }

    override fun onDestroy() {
        destroyed = true
        executor.shutdown()
        super.onDestroy()
    }
}
