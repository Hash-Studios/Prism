package com.hash.prism

import android.content.SharedPreferences

internal class WotdTileService : WallpaperTileService() {
    internal override fun isConfigured(prefs: SharedPreferences): Boolean =
        !prefs.getString("flutter.quick_tile.wotd.url", null).isNullOrBlank()

    internal override fun wallpaper(prefs: SharedPreferences): Wallpaper {
        val url = prefs.getString("flutter.quick_tile.wotd.url", null)?.trim()
        check(!url.isNullOrEmpty()) { "Open Prism to load today's Wall of the Day first" }
        return Wallpaper(url, TileWallpaperTarget.parse(prefs.getString("flutter.quick_tile.wotd.target", null)))
    }
}
