package com.hash.prism

import org.json.JSONObject
import java.io.File

internal object OfflineTileAssets {
    const val PATHS_PREFERENCE = "flutter.offline.native_asset_paths"
    const val CATEGORY_URLS_PREFERENCE = "flutter.quick_tile.category.wall_urls"


    fun retainedFile(source: String, rawPaths: String?, allowedRoots: List<File>): File? {
        val rawPath = try {
            JSONObject(rawPaths ?: return null).optString(source).takeIf(String::isNotBlank) ?: return null
        } catch (_: Exception) {
            return null
        }
        val file = try { File(rawPath).canonicalFile } catch (_: Exception) { return null }
        if (allowedRoots.none { root ->
                val canonicalRoot = try { root.canonicalFile } catch (_: Exception) { return@none false }
                file.path.startsWith(canonicalRoot.path + File.separator)
            }) return null
        if (!file.isFile || file.length() <= 0) return null
        return try {
            PrismImageValidation.mime(file)
            file
        } catch (_: Exception) {
            null
        }
    }
}
