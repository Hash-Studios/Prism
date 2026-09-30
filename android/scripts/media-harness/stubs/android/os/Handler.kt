package android.os

class Looper {
    companion object { @JvmStatic fun getMainLooper() = Looper() }
}

class Handler(looper: Looper) {
    fun post(action: () -> Unit): Boolean { action(); return true }
}
