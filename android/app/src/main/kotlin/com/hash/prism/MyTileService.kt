package com.hash.prism

import android.content.SharedPreferences
import org.json.JSONObject
import java.net.URLEncoder
import kotlin.random.Random

internal class MyTileService : WallpaperTileService() {
    internal override fun isConfigured(prefs: SharedPreferences): Boolean =
        !prefs.getString("flutter.quick_tile.category.name", null).isNullOrBlank()

    internal override fun wallpaper(prefs: SharedPreferences): Wallpaper {
        val category = prefs.getString("flutter.quick_tile.category.name", null)?.trim()
        check(!category.isNullOrEmpty()) { "Open Prism and configure the Quick Tile first" }
        val target = TileWallpaperTarget.parse(prefs.getString("flutter.quick_tile.category.target", null))
        val query = URLEncoder.encode(category, "UTF-8")
        val source = prefs.getString("flutter.quick_tile.category.source", PEXELS_SOURCE)?.trim()
        val link: String
        val headers: Map<String, String>
        when (source) {
            PEXELS_SOURCE -> {
                val key = prefs.getString("flutter.quick_tile.pexels.api_key", null)?.trim().orEmpty()
                check(key.isNotEmpty()) { "Open Prism to configure the wallpaper provider" }
                val page = Random.nextInt(1, 6)
                link = "https://api.pexels.com/v1/search?query=$query&per_page=30&orientation=portrait&page=$page"
                headers = mapOf("Authorization" to key, "Accept" to "application/json")
            }
            "wallhaven" -> {
                val categories = if ((prefs.getString("flutter.quick_tile.wallhaven.categories", null)?.trim()?.toIntOrNull() ?: 100) >= 110) "110" else "100"
                link = "https://wallhaven.cc/api/v1/search?q=$query&categories=$categories&purity=100&ratios=portrait&sorting=random&per_page=24"
                headers = mapOf("Accept" to "application/json")
            }
            else -> throw IllegalArgumentException("Unsupported wallpaper source")
        }
        val connection = PrismImageTransfer.openConnection(link, headers)
        val json = try {
            val bytes = java.io.ByteArrayOutputStream()
            connection.inputStream.use { PrismImageTransfer.copy(it, bytes, 2L * 1024 * 1024) }
            JSONObject(bytes.toString("UTF-8"))
        } finally { connection.disconnect() }
        val list = json.getJSONArray(if (source == PEXELS_SOURCE) "photos" else "data")
        check(list.length() > 0) { "No wallpaper found in this category" }
        val item = list.getJSONObject(Random.nextInt(list.length()))
        val url = if (source == PEXELS_SOURCE) item.getJSONObject("src").let { it.optString("large2x", "").ifEmpty { it.getString("original") } } else item.getString("path")
        return Wallpaper(url, target)
    }

    private companion object { const val PEXELS_SOURCE = "pexels" }
}
