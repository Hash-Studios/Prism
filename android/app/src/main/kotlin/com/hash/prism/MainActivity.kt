package com.hash.prism

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.hash.prism.pigeon.PrismMediaHostApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PrismMediaHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            PrismMediaHostApiImpl(this),
        )
    }
}
