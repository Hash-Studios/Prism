package com.hash.prism

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import com.hash.prism.pigeon.PrismMediaHostApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var mediaApi: PrismMediaHostApiImpl? = null
    private var hapticsChannel: MethodChannel? = null
    private val storagePermissions = LegacyStoragePermissionGate()

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val api = PrismMediaHostApiImpl(applicationContext) { callback ->
            storagePermissions.request(callback) {
                requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), STORAGE_PERMISSION_REQUEST)
            }
        }
        mediaApi = api
        PrismMediaHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            api,
        )
        val haptics = PrismHaptics(applicationContext)
        hapticsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prism/haptics").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "play") {
                    val type = PrismHapticType.fromWire(call.arguments)
                    if (type == null) result.error("INVALID_HAPTIC_TYPE", "Unknown haptic type", null)
                    else {
                        haptics.play(type)
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == STORAGE_PERMISSION_REQUEST) {
            storagePermissions.resolve(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        PrismMediaHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        hapticsChannel?.setMethodCallHandler(null)
        hapticsChannel = null
        storagePermissions.close()
        mediaApi?.close()
        mediaApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object { const val STORAGE_PERMISSION_REQUEST = 4201 }
}
