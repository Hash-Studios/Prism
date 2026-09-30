package android.content

class ContentValues {
    private val values = mutableMapOf<String, Any?>()

    fun put(key: String, value: String?) { values[key] = value }
    fun put(key: String, value: Int) { values[key] = value }
    operator fun get(key: String): Any? = values[key]
}
