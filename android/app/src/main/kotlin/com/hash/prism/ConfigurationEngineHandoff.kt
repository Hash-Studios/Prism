package com.hash.prism

internal class ConfigurationEngineHandoff<T : Any>(
    private val destroy: (T) -> Unit,
    private val postExpiry: (() -> Unit) -> Unit,
) {
    private class Pending<T>(val recreationKey: String, val engine: T, val frameworkHandlesBack: Boolean)
    private var pending: Pending<T>? = null

    fun owner(recreationKey: String): Owner = Owner(recreationKey)

    inner class Owner internal constructor(val recreationKey: String) {
        private var restoredBackState: Boolean? = null
        private var engine: T? = pending?.takeIf { it.recreationKey == recreationKey }?.let {
            pending = null
            restoredBackState = it.frameworkHandlesBack
            it.engine
        }
        private var released = false

        fun acquire(shellArgs: Array<String> = emptyArray(), create: (Array<String>) -> T): T {
            check(!released)
            return engine ?: create(shellArgs).also { engine = it }
        }

        fun restoreFrameworkHandlesBack(restore: (Boolean) -> Unit) {
            restoredBackState?.let(restore)
        }

        /** Call only after the fragment and its Activity-bound plugins have detached. */
        fun release(changingConfigurations: Boolean, finishing: Boolean, frameworkHandlesBack: Boolean? = null) {
            if (released) return
            released = true
            val releasedEngine = engine ?: return
            engine = null
            if (!changingConfigurations || finishing) {
                destroy(releasedEngine)
                return
            }

            val previous = pending
            val handoff = Pending(recreationKey, releasedEngine, frameworkHandlesBack ?: restoredBackState ?: false)
            pending = handoff
            previous?.let { destroy(it.engine) }
            postExpiry {
                if (pending === handoff) {
                    pending = null
                    destroy(handoff.engine)
                }
            }
        }
    }
}
