package android.graphics

import java.io.File

object BitmapFactory {
    class Options {
        var inJustDecodeBounds = false
        var outMimeType: String? = null
        var outWidth = 0
        var outHeight = 0
    }

    fun decodeFile(path: String, options: Options): Any? {
        val bytes = File(path).takeIf { it.exists() }?.readBytes() ?: return null
        if (bytes.size >= 24 && bytes.take(8) == listOf(137, 80, 78, 71, 13, 10, 26, 10).map(Int::toByte)) {
            options.outMimeType = "image/png"
            options.outWidth = readInt(bytes, 16)
            options.outHeight = readInt(bytes, 20)
        } else if (bytes.size >= 3 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xD8.toByte()) {
            options.outMimeType = "image/jpeg"
            options.outWidth = 1
            options.outHeight = 1
        } else if (bytes.size >= 12 && String(bytes, 8, 4) == "WEBP") {
            options.outMimeType = "image/webp"
            options.outWidth = 1
            options.outHeight = 1
        }
        return null
    }

    private fun readInt(bytes: ByteArray, offset: Int): Int =
        ((bytes[offset].toInt() and 255) shl 24) or
            ((bytes[offset + 1].toInt() and 255) shl 16) or
            ((bytes[offset + 2].toInt() and 255) shl 8) or
            (bytes[offset + 3].toInt() and 255)
}
