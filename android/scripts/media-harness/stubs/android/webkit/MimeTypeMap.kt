package android.webkit

class MimeTypeMap {
    fun getExtensionFromMimeType(mime: String): String? = when (mime) {
        "image/png" -> "png"
        "image/jpeg" -> "jpg"
        "image/webp" -> "webp"
        "image/gif" -> "gif"
        else -> null
    }
    companion object { @JvmStatic fun getSingleton() = MimeTypeMap() }
}
