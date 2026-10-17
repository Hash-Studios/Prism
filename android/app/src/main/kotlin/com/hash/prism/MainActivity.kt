package com.hash.prism

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.enableEdgeToEdge
import androidx.core.content.FileProvider
import com.hash.prism.pigeon.PrismAppIconHostApi
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
    private var hapticsChannel: MethodChannel? = null
    private var quickSettingsChannel: MethodChannel? = null
    private var systemColorsChannel: MethodChannel? = null
    private var wallpaperCropChannel: MethodChannel? = null
    private var engine: FlutterEngine? = null
    private var retainedBackState: Boolean? = null
    private val flutterFragment get() = supportFragmentManager.fragments.firstNotNullOfOrNull { it as? FlutterFragment }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        // The restored FlutterFragment turned Back handling off. Dart does not send it again for a kept engine.
        retainedBackState?.let { flutterFragment?.setFrameworkHandlesBack(it) }
    }

    // The default fragment destroys even a provided engine when it detaches. onDestroy owns the engine instead.
    override fun createFlutterFragment(): FlutterFragment =
        super.createFlutterFragment().apply { requireArguments().putBoolean("destroy_engine_with_fragment", false) }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        engine?.let { return it }
        val retained = engineHandoff.take()
        retainedBackState = retained?.frameworkHandlesBack
        val shellArgs = FlutterShellArgs.fromIntent(intent).toArray()
        val provided = retained?.engine ?: FlutterEngine(context.applicationContext, shellArgs).apply {
            plugins.add(PrismMediaPlugin())
        }
        return provided.also { engine = it }
    }

    override fun onDestroy() {
        val frameworkHandlesBack = flutterFragment?.backCallbackState ?: false
        super.onDestroy()
        val engine = engine ?: return
        this.engine = null
        // A new wallpaper changes the system colours and Android relaunches this Activity. Give the
        // engine to the new Activity so Dart keeps running. Any other destroy (Back) ends it.
        engineHandoff.release(engine, keep = isChangingConfigurations && !isFinishing, frameworkHandlesBack)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        PrismAppIconHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, PrismAppIconHostApiImpl(applicationContext))
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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        PrismAppIconHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        hapticsChannel?.setMethodCallHandler(null)
        hapticsChannel = null
        quickSettingsChannel?.setMethodCallHandler(null)
        quickSettingsChannel = null
        systemColorsChannel?.setMethodCallHandler(null)
        systemColorsChannel = null
        wallpaperCropChannel?.setMethodCallHandler(null)
        wallpaperCropChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object {
        val engineHandoff = ConfigurationEngineHandoff<FlutterEngine>(
            destroy = { it.destroy() },
            post = { task -> Handler(Looper.getMainLooper()).post { task() } },
        )
    }
}
