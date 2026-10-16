package com.hash.prism

import android.Manifest
import android.content.pm.PackageManager
import com.hash.prism.pigeon.PrismMediaHostApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Keeps the media API for the life of the engine. A config-change relaunch moves the engine to a new
 * Activity, so it must not cancel saves and downloads. Only the permission prompt needs the current Activity.
 */
internal class PrismMediaPlugin(
    private val attachApi: (FlutterPlugin.FlutterPluginBinding, ((Boolean) -> Unit) -> Unit) -> AutoCloseable = { binding, requestPermission ->
        PrismMediaHostApiImpl(binding.applicationContext, requestPermission).also {
            PrismMediaHostApi.setUp(binding.binaryMessenger, it)
        }
    },
    private val launchPermission: (ActivityPluginBinding) -> Unit = { binding ->
        binding.activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), STORAGE_PERMISSION_REQUEST)
    },
) : FlutterPlugin, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private val storagePermissions = LegacyStoragePermissionGate()
    private var activity: ActivityPluginBinding? = null
    private var api: AutoCloseable? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        api = attachApi(binding, ::requestStoragePermission)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PrismMediaHostApi.setUp(binding.binaryMessenger, null)
        storagePermissions.close()
        api?.close()
        api = null
    }

    // A prompt that is open stays pending: Android gives its result to the replacement Activity.
    fun requestStoragePermission(callback: (Boolean) -> Unit) = storagePermissions.request(callback) {
        launchPermission(checkNotNull(activity) { "No Activity attached" })
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        if (requestCode != STORAGE_PERMISSION_REQUEST) return false
        storagePermissions.resolve(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity?.removeRequestPermissionsResultListener(this)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    private companion object {
        const val STORAGE_PERMISSION_REQUEST = 4201
    }
}
