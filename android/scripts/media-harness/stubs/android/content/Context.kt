package android.content

import java.io.File

open class Context(
    val contentResolver: ContentResolver = ContentResolver(),
    val cacheDir: File = createCacheDir(),
) {
    fun getSystemService(name: String): Any? = null

    companion object {
        const val DOWNLOAD_SERVICE = "download"
        private fun createCacheDir(): File = File(System.getProperty("java.io.tmpdir"), "media-harness-cache").apply {
            mkdirs()
        }
    }
}
