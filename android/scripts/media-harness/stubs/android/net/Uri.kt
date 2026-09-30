package android.net

class Uri private constructor(private val value: String) {
    val path: String? get() = runCatching { java.net.URI(value).path }.getOrNull()
    val lastPathSegment: String? get() = path?.substringAfterLast('/')
    override fun toString(): String = value

    companion object {
        @JvmStatic fun parse(value: String): Uri = Uri(value)
    }
}
