package com.hash.prism

internal class LegacyStoragePermissionGate {
    private val pending = mutableListOf<(Boolean) -> Unit>()
    private var closed = false

    fun request(callback: (Boolean) -> Unit, launch: () -> Unit) {
        if (closed) { callback(false); return }
        pending.add(callback)
        if (pending.size == 1) {
            try { launch() } catch (_: Exception) { resolve(false) }
        }
    }

    fun resolve(granted: Boolean) {
        val callbacks = pending.toList()
        pending.clear()
        callbacks.forEach { it(granted) }
    }

    fun close() { closed = true; resolve(false) }
}
