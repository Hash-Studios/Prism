package com.hash.Prism;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.bumptech.glide.request.target.CustomTarget;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.app.WallpaperManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Drawable;

import io.flutter.embedding.android.FlutterActivity;
import com.bumptech.glide.Glide;
import com.bumptech.glide.request.RequestOptions;
import com.bumptech.glide.request.transition.Transition;

import java.io.IOException;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "flutter.prism.set_wallpaper";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("set_wallpaper")){

                                String url = call.argument("url"); // .argument returns the correct type
                                android.util.Log.i("Arguments ", "configureFlutterEngine: "+url);

                                Glide.with(getActivity())
                                        .asBitmap()
                                        .load(url)
                                        .into(new CustomTarget<Bitmap>() {
                                            @Override
                                            public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                                android.util.Log.i("Arguments ", "configureFlutterEngine: "+"Ready");
                                                WallpaperManager wallpaperManager = WallpaperManager.getInstance(getApplicationContext());
                                                try {
                                                    wallpaperManager.setBitmap(resource);
                                                    result.success(true);
                                                } catch (IOException ex) {
                                                    ex.printStackTrace();
                                                }
                                            }
                                            @Override
                                            public void onLoadCleared(@Nullable Drawable placeholder) {
                                            }
                                        });

                            }
                        }
                );
    }
}