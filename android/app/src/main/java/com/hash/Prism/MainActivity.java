package com.hash.prism;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

import com.hash.prism.pigeon.PrismMediaApi.PrismMediaHostApi;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        PrismMediaHostApi.setUp(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            new PrismMediaHostApiImpl(this)
        );
    }
}
