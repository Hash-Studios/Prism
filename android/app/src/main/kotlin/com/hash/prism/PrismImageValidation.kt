package com.hash.prism

import android.graphics.BitmapFactory
import java.io.File
import java.io.IOException

internal object PrismImageValidation {
    fun mime(file: File): String {
        if (!file.isFile || file.length() <= 0 || file.length() > PrismImageTransfer.MAX_IMAGE_BYTES) throw IOException("Invalid image file")
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        val mime = bounds.outMimeType
        if (mime == null || !mime.startsWith("image/") || bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw IOException("Invalid image")
        }
        // Bounds alone accept a valid header with a corrupt body. Decode at most about one megapixel.
        var sample = 1
        while (bounds.outWidth / sample > 1024 || bounds.outHeight / sample > 1024) sample *= 2
        val decoded = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IOException("Could not decode image")
        decoded.recycle()
        return mime
    }
}
