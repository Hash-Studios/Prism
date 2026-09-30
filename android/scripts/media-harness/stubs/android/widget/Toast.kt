package android.widget

import android.content.Context

class Toast {
    fun show() {}
    companion object {
        const val LENGTH_SHORT = 0
        @JvmStatic fun makeText(context: Context, text: String, duration: Int) = Toast()
    }
}
