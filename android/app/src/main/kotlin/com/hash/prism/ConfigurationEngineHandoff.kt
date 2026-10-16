package com.hash.prism

/**
 * Gives the engine of an Activity destroyed by a config change to the Activity that replaces it.
 * Android destroys and recreates the Activity in one main-thread message, so [post] runs after the
 * replacement had its chance to [take] the engine. An engine nobody took is destroyed then.
 */
internal class ConfigurationEngineHandoff<T : Any>(
    private val destroy: (T) -> Unit,
    private val post: (() -> Unit) -> Unit,
) {
    class Retained<T>(val engine: T, val frameworkHandlesBack: Boolean)

    private var retained: Retained<T>? = null

    fun take(): Retained<T>? = retained.also { retained = null }

    /** Call after the fragment has detached from [engine]. Keeps it for the next Activity only if [keep]. */
    fun release(engine: T, keep: Boolean, frameworkHandlesBack: Boolean) {
        if (!keep) return destroy(engine)
        retained?.let { destroy(it.engine) }
        val handoff = Retained(engine, frameworkHandlesBack)
        retained = handoff
        post {
            if (retained === handoff) {
                retained = null
                destroy(engine)
            }
        }
    }
}
