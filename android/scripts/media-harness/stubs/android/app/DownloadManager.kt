package android.app

import android.net.Uri

class DownloadManager {
    fun enqueue(request: Request): Long = 1L

    class Request(uri: Uri) {
        fun setAllowedNetworkTypes(value: Int) = this
        fun setAllowedOverRoaming(value: Boolean) = this
        fun setTitle(value: String) = this
        fun setDescription(value: String) = this
        fun setMimeType(value: String) = this
        fun setNotificationVisibility(value: Int) = this
        fun setDestinationInExternalPublicDir(directory: String, path: String) = this

        companion object {
            const val NETWORK_WIFI = 1
            const val NETWORK_MOBILE = 2
            const val VISIBILITY_VISIBLE_NOTIFY_COMPLETED = 1
        }
    }
}
