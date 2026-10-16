package com.hash.prism

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Proxy

internal class PrismMediaPluginTest {
    /** An Activity binding. JVM tests have no Activity, so a prompt counts the lookup and then fails. */
    private class Activity {
        var prompts = 0
        val listeners = mutableListOf<Any>()
        val binding = Proxy.newProxyInstance(javaClass.classLoader, arrayOf(ActivityPluginBinding::class.java)) { _, method, args ->
            when (method.name) {
                "getActivity" -> { prompts++; throw UnsupportedOperationException("No Activity in JVM tests") }
                "addRequestPermissionsResultListener" -> listeners.add(args[0])
                "removeRequestPermissionsResultListener" -> listeners.remove(args[0])
            }
            null
        } as ActivityPluginBinding
    }

    private val plugin = PrismMediaPlugin()
    private val results = mutableListOf<Boolean>()

    @Test internal fun permissionRequestsGoToTheCurrentActivityAndFailWithoutOne() {
        plugin.requestStoragePermission { results.add(it) }

        val old = Activity()
        plugin.onAttachedToActivity(old.binding)
        plugin.requestStoragePermission { results.add(it) }
        assertEquals(listOf<Any>(plugin), old.listeners)

        plugin.onDetachedFromActivityForConfigChanges()
        plugin.requestStoragePermission { results.add(it) }
        assertTrue(old.listeners.isEmpty())

        val replacement = Activity()
        plugin.onReattachedToActivityForConfigChanges(replacement.binding)
        plugin.requestStoragePermission { results.add(it) }

        assertEquals(listOf(1, 1), listOf(old.prompts, replacement.prompts))
        assertEquals(listOf(false, false, false, false), results)
        assertEquals(listOf<Any>(plugin), replacement.listeners)
    }

    @Test internal fun onlyTheStorageRequestResultIsHandled() {
        assertFalse(plugin.onRequestPermissionsResult(1, emptyArray(), intArrayOf()))
        assertTrue(plugin.onRequestPermissionsResult(4201, emptyArray(), intArrayOf()))
    }
}
