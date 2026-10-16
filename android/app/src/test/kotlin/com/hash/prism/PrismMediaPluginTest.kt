package com.hash.prism

import com.hash.prism.pigeon.DownloadItemsResult
import com.hash.prism.pigeon.DownloadRequest
import com.hash.prism.pigeon.OperationResult
import com.hash.prism.pigeon.PrismMediaHostApi
import com.hash.prism.pigeon.SaveMediaKind
import com.hash.prism.pigeon.SaveMediaRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.PluginRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Proxy
import java.nio.ByteBuffer

internal class PrismMediaPluginTest {
    private class Messenger : BinaryMessenger {
        val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()
        override fun send(channel: String, message: ByteBuffer?) = Unit
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            if (handler == null) handlers.remove(channel) else handlers[channel] = handler
        }

        fun call(name: String, arguments: List<Any?>): MutableList<Any?> {
            val result = mutableListOf<Any?>()
            val message = PrismMediaHostApi.codec.encodeMessage(arguments)?.apply { flip() }
            handlers.getValue(name).onMessage(message, object : BinaryMessenger.BinaryReply {
                override fun reply(reply: ByteBuffer?) {
                    val envelope = PrismMediaHostApi.codec.decodeMessage(reply?.apply { flip() }) as List<*>
                    result.add(envelope.single())
                }
            })
            return result
        }
    }

    private class Activity {
        val listeners = mutableListOf<PluginRegistry.RequestPermissionsResultListener>()
        val binding = Proxy.newProxyInstance(javaClass.classLoader, arrayOf(ActivityPluginBinding::class.java)) { _, method, args ->
            when (method.name) {
                "addRequestPermissionsResultListener" -> listeners.add(args!![0] as PluginRegistry.RequestPermissionsResultListener)
                "removeRequestPermissionsResultListener" -> listeners.remove(args!![0] as PluginRegistry.RequestPermissionsResultListener)
                else -> Unit
            }
            null
        } as ActivityPluginBinding
    }

    private class HostApi : PrismMediaHostApi, AutoCloseable {
        val pending = mutableListOf<(Result<OperationResult>) -> Unit>()
        var closes = 0
        override fun saveMedia(request: SaveMediaRequest, callback: (Result<OperationResult>) -> Unit) { pending.add(callback) }
        override fun enqueueDownload(request: DownloadRequest, callback: (Result<OperationResult>) -> Unit) { pending.add(callback) }
        override fun listDownloads(callback: (Result<DownloadItemsResult>) -> Unit) {
            callback(Result.success(DownloadItemsResult(true, listOf("a.jpg"))))
        }
        override fun clearDownloads(callback: (Result<OperationResult>) -> Unit) { pending.add(callback) }
        override fun deleteDownload(path: String, callback: (Result<OperationResult>) -> Unit) { pending.add(callback) }
        override fun close() { closes++ }
    }

    private fun binding(messenger: BinaryMessenger) = FlutterPlugin.FlutterPluginBinding::class.java.constructors.single()
        .newInstance(null, null, messenger, null, null, null, null) as FlutterPlugin.FlutterPluginBinding
    private val channelNames = listOf("saveMedia", "enqueueDownload", "listDownloads", "clearDownloads", "deleteDownload")
        .map { "dev.flutter.pigeon.Prism.PrismMediaHostApi.$it" }

    private fun plugin(api: HostApi, attaches: () -> Unit = {}) = PrismMediaPlugin(
        attachApi = { engine, _ ->
            attaches()
            PrismMediaHostApi.setUp(engine.binaryMessenger, api)
            api
        },
        launchPermission = {},
    )

    @Test fun apiAndPigeonHandlersSurviveActivityConfigurationChangesUntilEngineDetach() {
        val messenger = Messenger()
        val host = HostApi()
        var attaches = 0
        val plugin = plugin(host) { attaches++ }
        val engine = binding(messenger)
        plugin.onAttachedToEngine(engine)
        val old = Activity()
        plugin.onAttachedToActivity(old.binding)
        val pendingSave = messenger.call(channelNames[0], listOf(SaveMediaRequest("url", false, SaveMediaKind.WALLPAPER)))
        val pendingDownload = messenger.call(channelNames[1], listOf(DownloadRequest("url", "file", false)))
        assertEquals(listOf(DownloadItemsResult(true, listOf("a.jpg"))), messenger.call(channelNames[2], emptyList()))
        assertEquals(2, host.pending.size)
        val registeredHandlers = messenger.handlers.toMap()

        plugin.onDetachedFromActivityForConfigChanges()
        assertTrue(old.listeners.isEmpty())
        val replacement = Activity()
        plugin.onReattachedToActivityForConfigChanges(replacement.binding)
        assertEquals(channelNames.toSet(), messenger.handlers.keys)
        channelNames.forEach { assertSame(registeredHandlers[it], messenger.handlers[it]) }
        assertEquals(1, attaches)
        assertEquals(0, host.closes)
        assertEquals(2, host.pending.size)

        host.pending[0](Result.success(OperationResult(true)))
        host.pending[1](Result.success(OperationResult(false, "DENIED", "no")))
        assertEquals(listOf(OperationResult(true)), pendingSave)
        assertEquals(listOf(OperationResult(false, "DENIED", "no")), pendingDownload)
        plugin.onDetachedFromActivity()
        assertEquals(0, host.closes)
        plugin.onDetachedFromEngine(engine)
        assertTrue(messenger.handlers.isEmpty())
        assertEquals(1, host.closes)
        assertTrue(replacement.listeners.isEmpty())
    }

    @Test fun pendingPermissionMovesToReplacementActivityAndEmptyGrantDeniesNextRequest() {
        val launched = mutableListOf<ActivityPluginBinding>()
        val plugin = PrismMediaPlugin(attachApi = { _, _ -> AutoCloseable {} }, launchPermission = { launched.add(it) })
        val results = mutableListOf<Boolean>()
        val old = Activity()
        plugin.onAttachedToActivity(old.binding)
        plugin.requestStoragePermission(results::add)
        plugin.requestStoragePermission(results::add)
        assertEquals(1, launched.size)
        assertSame(old.binding, launched.single())
        plugin.onDetachedFromActivityForConfigChanges()
        assertTrue(old.listeners.isEmpty())
        val replacement = Activity()
        plugin.onReattachedToActivityForConfigChanges(replacement.binding)
        assertFalse(replacement.listeners.single().onRequestPermissionsResult(1, emptyArray(), intArrayOf()))
        assertTrue(replacement.listeners.single().onRequestPermissionsResult(4201, emptyArray(), intArrayOf(0)))
        assertEquals(listOf(true, true), results)
        replacement.listeners.single().onRequestPermissionsResult(4201, emptyArray(), intArrayOf())
        assertEquals(listOf(true, true), results)
        plugin.requestStoragePermission(results::add)
        assertEquals(2, launched.size)
        assertSame(old.binding, launched[0])
        assertSame(replacement.binding, launched[1])
        replacement.listeners.single().onRequestPermissionsResult(4201, emptyArray(), intArrayOf())
        assertEquals(listOf(true, true, false), results)
        replacement.listeners.single().onRequestPermissionsResult(4201, emptyArray(), intArrayOf(0))
        assertEquals(listOf(true, true, false), results)
    }

    @Test fun requestsWithoutActivityAndEngineDetachDenyPendingPermission() {
        val launches = mutableListOf<ActivityPluginBinding>()
        val noActivityPlugin = PrismMediaPlugin(attachApi = { _, _ -> AutoCloseable {} }, launchPermission = { launches.add(it) })
        val results = mutableListOf<Boolean>()
        noActivityPlugin.requestStoragePermission(results::add)
        assertEquals(listOf(false), results)
        val messenger = Messenger()
        val host = HostApi()
        val engine = binding(messenger)
        val attached = plugin(host)
        attached.onAttachedToEngine(engine)
        val activity = Activity()
        attached.onAttachedToActivity(activity.binding)
        attached.requestStoragePermission(results::add)
        attached.onDetachedFromActivity()
        assertEquals(0, host.closes)
        attached.onDetachedFromEngine(engine)
        assertEquals(listOf(false, false), results)
    }
}
