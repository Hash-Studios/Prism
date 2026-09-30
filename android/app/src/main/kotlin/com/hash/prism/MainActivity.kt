package com.hash.prism

import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import com.hash.prism.pigeon.PrismMediaHostApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun onPostResume() {
        super.onPostResume()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Flutter 3.47.5 resets these legacy flags on resume; its edge-to-edge path starts at API 29.
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PrismMediaHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            PrismMediaHostApiImpl(this),
        )
    }
}
