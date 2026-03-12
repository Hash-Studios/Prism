package com.hash.prism

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Environment
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import android.widget.Toast
import androidx.annotation.RequiresApi
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.Random

@RequiresApi(api = Build.VERSION_CODES.N)
class MyTileService : TileService() {
    companion object {
        private const val LOG = "Prism::"

        fun getFolderSize(file: File): Long {
            if (!file.isDirectory) {
                return file.length()
            }
            var size = 0L
            file.listFiles()?.forEach { child ->
                size += getFolderSize(child)
            }
            return size
        }
    }

    private fun setWallpaper(context: Context) {
        val qsTile = qsTile
        qsTile?.state = Tile.STATE_ACTIVE
        qsTile?.updateTile()
        Log.d(LOG, "onReceive: clicked")

        val path = if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q) {
            Environment.getExternalStorageDirectory().toString() + "/Pictures/Prism"
        } else {
            Environment.getExternalStorageDirectory().toString() + "/Prism"
        }

        val candidates = File(path).listFiles()?.filter { file ->
            getFolderSize(file) / 1_048_576 < 5
        }.orEmpty()

        if (candidates.isEmpty()) {
            Toast.makeText(this, "No wallpapers downloaded!", Toast.LENGTH_SHORT).show()
            qsTile?.state = Tile.STATE_INACTIVE
            qsTile?.updateTile()
            return
        }

        try {
            val randomFile = candidates[Random().nextInt(candidates.size)]
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }

            val bitmap = FileInputStream(randomFile).use { input ->
                BitmapFactory.decodeStream(input, null, options)
            }

            if (bitmap == null) {
                Toast.makeText(this, "No wallpapers downloaded!", Toast.LENGTH_SHORT).show()
            } else {
                val wallpaperManager = WallpaperManager.getInstance(context)
                try {
                    wallpaperManager.setBitmap(
                        bitmap,
                        null,
                        false,
                        WallpaperManager.FLAG_LOCK or WallpaperManager.FLAG_SYSTEM,
                    )
                    Log.d("TAG", "onBitmapLoaded: ${bitmap == null}")
                } catch (e: IOException) {
                    e.printStackTrace()
                } finally {
                    bitmap.recycle()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(this, "No wallpapers downloaded!", Toast.LENGTH_SHORT).show()
        }

        qsTile?.state = Tile.STATE_INACTIVE
        qsTile?.updateTile()
    }

    override fun onClick() {
        super.onClick()
        setWallpaper(applicationContext)
    }

    override fun onTileAdded() {
        super.onTileAdded()
        val qsTile = qsTile
        qsTile?.state = Tile.STATE_INACTIVE
        qsTile?.updateTile()
    }
}
