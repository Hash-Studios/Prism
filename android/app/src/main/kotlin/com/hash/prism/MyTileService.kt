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
        var firstPageLink: String? = null
        when (source) {
            PEXELS_SOURCE -> {
                val key = prefs.getString("flutter.quick_tile.pexels.api_key", null)?.trim().orEmpty()
                check(key.isNotEmpty()) { "Open Prism to configure the wallpaper provider" }
                val page = Random.nextInt(1, 6)
                val base = "https://api.pexels.com/v1/search?query=$query&per_page=30&orientation=portrait&page="
                link = base + page
                if (page > 1) firstPageLink = base + 1
                headers = mapOf("Authorization" to key, "Accept" to "application/json")
            }
            "wallhaven" -> {
                val categories = if ((prefs.getString("flutter.quick_tile.wallhaven.categories", null)?.trim()?.toIntOrNull() ?: 100) >= 110) "110" else "100"
                link = "https://wallhaven.cc/api/v1/search?q=$query&categories=$categories&purity=100&ratios=portrait&sorting=random&per_page=24"
                headers = mapOf("Accept" to "application/json")
            }
            else -> throw IllegalArgumentException("Unsupported wallpaper source")
        }
        val listKey = if (source == PEXELS_SOURCE) "photos" else "data"
        var json = fetchJson(link, headers)
        if (firstPageLink != null && json.getJSONArray(listKey).length() == 0) {
            json = fetchJson(firstPageLink, headers)
        }
        val list = json.getJSONArray(listKey)
        check(list.length() > 0) { "No wallpaper found in this category" }
        val item = list.getJSONObject(Random.nextInt(list.length()))
        val url = if (source == PEXELS_SOURCE) item.getJSONObject("src").let { it.optString("large2x", "").ifEmpty { it.getString("original") } } else item.getString("path")
        return Wallpaper(url, target)
    }

    private fun fetchJson(link: String, headers: Map<String, String>): JSONObject {
        val connection = PrismImageTransfer.openConnection(link, headers)
        return try {
            val bytes = java.io.ByteArrayOutputStream()
            connection.inputStream.use { PrismImageTransfer.copy(it, bytes, 2L * 1024 * 1024) }
            JSONObject(bytes.toString("UTF-8"))
        } finally { connection.disconnect() }
    }

    private companion object { const val PEXELS_SOURCE = "pexels" }
}
