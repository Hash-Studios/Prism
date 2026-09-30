package android.os

import java.io.File

object Environment {
    const val DIRECTORY_PICTURES = "Pictures"
    var externalStorageRoot: File = File(System.getProperty("java.io.tmpdir"), "media-harness-public")
    @JvmStatic fun getExternalStoragePublicDirectory(type: String): File = File(externalStorageRoot, type)
    @JvmStatic fun getExternalStorageDirectory(): File = externalStorageRoot
}
