package android.database

interface Cursor : java.io.Closeable {
    fun getColumnIndex(name: String): Int
    fun getString(columnIndex: Int): String
    fun moveToNext(): Boolean
}
