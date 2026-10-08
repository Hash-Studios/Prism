package com.hash.prism

import android.content.SharedPreferences
import org.json.JSONArray
import kotlin.random.Random

internal class FavsTileService : WallpaperTileService() {
    internal override fun isConfigured(prefs: SharedPreferences): Boolean {
        val raw = prefs.getString("flutter.quick_tile.favs.wall_urls", null)
        return !raw.isNullOrBlank() && raw.trim() != "[]"
    }

    internal override fun wallpaper(prefs: SharedPreferences): Wallpaper {
        val raw = prefs.getString("flutter.quick_tile.favs.wall_urls", null)
            ?: throw IllegalStateException("Open Prism and save some favourite wallpapers first")
        val array = JSONArray(raw)
        val urls = (0 until array.length()).mapNotNull { (array.opt(it) as? String)?.trim()?.takeIf(String::isNotEmpty) }
        check(urls.isNotEmpty()) { "Open Prism and save some favourite wallpapers first" }
        return Wallpaper(urls[Random.nextInt(urls.size)], TileWallpaperTarget.parse(prefs.getString("flutter.quick_tile.favs.target", null)))
    }
}
