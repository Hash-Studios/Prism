package android.content

import android.net.Uri
import android.database.Cursor
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream

open class ContentResolver {
    var failOutputAfterBytes: Int? = null
    var failPublish = false
    var insertedValues: ContentValues? = null
    var updatedValues: ContentValues? = null
    var outputBytes = ByteArrayOutputStream()
    var outputClosed = false
    var deleteCount = 0
    var updateCount = 0

    open fun insert(uri: Uri, values: ContentValues): Uri? {
        insertedValues = values
        return Uri.parse("content://media/item/1")
    }

    open fun openOutputStream(uri: Uri): OutputStream? = object : OutputStream() {
        override fun write(value: Int) {
            if (failOutputAfterBytes != null && outputBytes.size() >= failOutputAfterBytes!!) {
                throw IOException("injected output failure")
            }
            outputBytes.write(value)
        }

        override fun write(bytes: ByteArray, offset: Int, length: Int) {
            val remaining = failOutputAfterBytes?.minus(outputBytes.size())
            if (remaining != null && length > remaining) {
                if (remaining > 0) outputBytes.write(bytes, offset, remaining)
                throw IOException("injected output failure")
            }
            outputBytes.write(bytes, offset, length)
        }

        override fun close() { outputClosed = true }
    }

    open fun update(uri: Uri, values: ContentValues, where: String?, args: Array<String>?): Int {
        updateCount++
        updatedValues = values
        return if (failPublish) 0 else 1
    }

    open fun delete(uri: Uri, where: String?, args: Array<String>?): Int {
        deleteCount++
        return 1
    }

    open fun query(
        uri: Uri,
        projection: Array<String>,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?,
    ): Cursor? = null
}
