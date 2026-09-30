package com.hash.prism

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import com.hash.prism.pigeon.PrismMediaHostApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

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
    }
}
