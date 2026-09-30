package android.provider

import android.net.Uri

object MediaStore {
    object MediaColumns {
        const val DISPLAY_NAME = "display_name"
        const val MIME_TYPE = "mime_type"
        const val RELATIVE_PATH = "relative_path"
        const val IS_PENDING = "is_pending"
    }
    object Images {
        object Media {
            @JvmField val EXTERNAL_CONTENT_URI = Uri.parse("content://media/images")
            const val DATA = "_data"
            const val RELATIVE_PATH = "relative_path"
            const val DISPLAY_NAME = "display_name"
            const val DATE_ADDED = "date_added"
        }
    }
}
