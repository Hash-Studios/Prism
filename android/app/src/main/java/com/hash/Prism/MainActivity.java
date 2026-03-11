package com.hash.prism;

import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.core.view.WindowCompat;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

import com.hash.prism.pigeon.PrismMediaApi.PrismMediaHostApi;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        PrismMediaHostApi.setUp(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            new PrismMediaHostApiImpl(this)
        );
    }
}
