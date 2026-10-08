package com.hash.prism

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.content.FileProvider
import com.hash.prism.pigeon.PrismMediaHostApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var mediaApi: PrismMediaHostApiImpl? = null
    private var hapticsChannel: MethodChannel? = null
    private var wallpaperCropChannel: MethodChannel? = null
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
        wallpaperCropChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prism/wallpaper_crop").apply {
            setMethodCallHandler { call, result ->
                val path = call.arguments as? String
                if (call.method != "contentUri") {
                    result.notImplemented()
                } else if (path.isNullOrBlank()) {
                    result.error("INVALID_PATH", "A file path is required", null)
                } else {
                    Thread {
                        try {
                            val uri = cropContentUri(path)
                            runOnUiThread { result.success(uri) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("CROP_SOURCE_FAILED", error.message, null) }
                        }
                    }.start()
                }
            }
        }
    }

    /** The system cropper reads only content URIs. Copies [path] into the shared cache folder and returns its URI. */
    private fun cropContentUri(path: String): String {
        val source = File(path)
        val folder = File(cacheDir, "wallpaper_crop").apply { mkdirs() }
        folder.listFiles()?.forEach { it.delete() }
        val copy = source.copyTo(File(folder, "wallpaper.${source.extension.ifBlank { "jpg" }}"), overwrite = true)
        return FileProvider.getUriForFile(this, "$packageName.wallpaper_crop", copy).toString()
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
        wallpaperCropChannel?.setMethodCallHandler(null)
        wallpaperCropChannel = null
        storagePermissions.close()
        mediaApi?.close()
        mediaApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object { const val STORAGE_PERMISSION_REQUEST = 4201 }
}
