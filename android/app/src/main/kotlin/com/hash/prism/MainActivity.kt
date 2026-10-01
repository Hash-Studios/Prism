package com.hash.prism

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import com.hash.prism.pigeon.PrismMediaHostApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PrismMediaHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            PrismMediaHostApiImpl(this),
        )
        val haptics = PrismHaptics(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prism/haptics").setMethodCallHandler { call, result ->
            if (call.method == "play") {
                haptics.play(call.arguments as? String ?: "tap")
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
