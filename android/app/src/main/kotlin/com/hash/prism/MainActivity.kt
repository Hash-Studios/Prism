package com.hash.prism

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.enableEdgeToEdge
import androidx.core.content.FileProvider
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentManager
import com.hash.prism.pigeon.PrismMediaHostApi
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

internal fun copyWallpaperCropFile(source: File, folder: File): File {
    folder.mkdirs()
    val destination = File.createTempFile("wallpaper_crop_", ".${source.extension.ifBlank { "jpg" }}", folder)
    return try {
        source.copyTo(destination, overwrite = true)
    } catch (error: Exception) {
        destination.delete()
        throw error
    }
}

class MainActivity : FlutterFragmentActivity() {
    private var mediaApi: PrismMediaHostApiImpl? = null
    private var hapticsChannel: MethodChannel? = null
    private var quickSettingsChannel: MethodChannel? = null
    private var systemColorsChannel: MethodChannel? = null
    private var wallpaperCropChannel: MethodChannel? = null
    private val storagePermissions = LegacyStoragePermissionGate()
    private lateinit var engineOwner: ConfigurationEngineHandoff<FlutterEngine>.Owner

    override fun onCreate(savedInstanceState: Bundle?) {
        // Claim before super: FragmentManager may attach a restored fragment during onCreate.
        engineOwner = engineHandoff.owner(
            savedInstanceState?.getString(ENGINE_RECREATION_KEY) ?: UUID.randomUUID().toString(),
        )
        supportFragmentManager.registerFragmentLifecycleCallbacks(
            object : FragmentManager.FragmentLifecycleCallbacks() {
                override fun onFragmentCreated(fm: FragmentManager, f: Fragment, savedInstanceState: Bundle?) {
                    if (f !is FlutterFragment) return
                    // FlutterFragment.onCreate resets Back handling after its engine has attached.
                    engineOwner.restoreFrameworkHandlesBack(f::setFrameworkHandlesBack)
                    fm.unregisterFragmentLifecycleCallbacks(this)
                }
            },
            false,
        )
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString(ENGINE_RECREATION_KEY, engineOwner.recreationKey)
        super.onSaveInstanceState(outState)
    }

    // The default fragment destroys even a provided engine when it detaches. onDestroy owns the engine instead.
    override fun createFlutterFragment(): FlutterFragment =
        super.createFlutterFragment().apply { requireArguments().putBoolean("destroy_engine_with_fragment", false) }

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        engineOwner.acquire(FlutterShellArgs.fromIntent(intent).toArray()) { shellArgs ->
            FlutterEngine(context.applicationContext, shellArgs)
        }

    override fun onDestroy() {
        val frameworkHandlesBack = supportFragmentManager.fragments.filterIsInstance<FlutterFragment>()
            .firstOrNull()?.backCallbackState
        super.onDestroy()
        engineOwner.release(isChangingConfigurations, isFinishing, frameworkHandlesBack)
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
        val quickSettings = PrismQuickSettings(this)
        quickSettingsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prism/quick_settings").apply {
            setMethodCallHandler(quickSettings::handle)
        }
        val systemColors = PrismSystemColors(this)
        systemColorsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prism/system_colors").apply {
            setMethodCallHandler(systemColors::handle)
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
        val copy = copyWallpaperCropFile(source, File(cacheDir, "wallpaper_crop"))
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
        quickSettingsChannel?.setMethodCallHandler(null)
        quickSettingsChannel = null
        systemColorsChannel?.setMethodCallHandler(null)
        systemColorsChannel = null
        wallpaperCropChannel?.setMethodCallHandler(null)
        wallpaperCropChannel = null
        storagePermissions.close()
        mediaApi?.close()
        mediaApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object {
        const val STORAGE_PERMISSION_REQUEST = 4201
        const val ENGINE_RECREATION_KEY = "prism.engine_recreation_key"

        private val engineHandoff = ConfigurationEngineHandoff<FlutterEngine>(
            destroy = { it.destroy() },
            postExpiry = { expiry -> Handler(Looper.getMainLooper()).post { expiry() } },
        )
    }
}
