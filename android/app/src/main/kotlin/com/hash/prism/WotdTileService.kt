package com.hash.prism

import android.content.SharedPreferences

internal class WotdTileService : WallpaperTileService() {
    internal override fun isConfigured(prefs: SharedPreferences): Boolean = source(prefs) != null

    internal override fun wallpaper(prefs: SharedPreferences): Wallpaper {
        val source = source(prefs)
        check(source != null) { "Open Prism to load today's Wall of the Day first" }
        return Wallpaper(source, TileWallpaperTarget.parse(prefs.getString("flutter.quick_tile.wotd.target", null)))
    }

    private fun source(prefs: SharedPreferences): String? =
        tileSource(prefs.getString("flutter.quick_tile.wotd.url", null), prefs.getString(RETAINED_PREFERENCE, null))

    internal companion object {
        const val RETAINED_PREFERENCE = "flutter.quick_tile.wotd.retained"
        private val RETAINED_KEY = Regex("\"assetKey\"\\s*:\\s*\"(wotd:[^\"\\\\]+)\"")

        /** The public URL, or for a protected wall with no public URL, the key of the original the user downloaded. */
        internal fun tileSource(rawUrl: String?, rawRetained: String?): String? =
            rawUrl?.trim()?.takeIf(String::isNotEmpty)
                ?: rawRetained?.let { RETAINED_KEY.find(it)?.groupValues?.get(1) }
    }
}
