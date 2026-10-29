package com.hash.prism

import android.content.SharedPreferences

internal class WotdTileService : WallpaperTileService() {
    internal override fun isConfigured(prefs: SharedPreferences): Boolean = source(prefs) != null || appLink(prefs) != null

    internal override fun appLink(prefs: SharedPreferences): String? =
        openLink(source(prefs), readPreferenceString { prefs.getString(LINK_PREFERENCE, null) })

    internal override fun wallpaper(prefs: SharedPreferences): Wallpaper {
        val source = source(prefs)
        check(source != null) { "Open Prism to load today's Wall of the Day first" }
        return Wallpaper(
            source,
            TileWallpaperTarget.parse(prefs.getString("flutter.quick_tile.wotd.target", null)),
        )
    }

    private fun source(prefs: SharedPreferences): String? =
        tileSource(
            readPreferenceString { prefs.getString("flutter.quick_tile.wotd.url", null) },
            readPreferenceString { prefs.getString(RETAINED_PREFERENCE, null) },
        )

    internal companion object {
        const val RETAINED_PREFERENCE = "flutter.quick_tile.wotd.retained"
        const val LINK_PREFERENCE = "flutter.quick_tile.wotd.open_link"
        private val RETAINED_KEY = Regex("\"assetKey\"\\s*:\\s*\"(wotd:[^\"\\\\]+)\"")

        /** The public URL, or for a protected wall with no public URL, the key of the original the user downloaded. */
        internal fun tileSource(rawUrl: String?, rawRetained: String?): String? =
            rawUrl?.trim()?.takeIf(String::isNotEmpty)
                ?: rawRetained?.let { RETAINED_KEY.find(it)?.groupValues?.get(1) }

        /** Today's wall in Prism, for a protected wall the tile cannot set. Null when the tile can set a wallpaper. */
        internal fun openLink(source: String?, rawLink: String?): String? =
            if (source != null) null else rawLink?.trim()?.takeIf { it.startsWith("prism://share?") }
    }
}
