package com.hash.prism;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.content.Intent;
import android.net.*;

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
                            if (call.method.equals("set_lock_wallpaper")){

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
                                                    wallpaperManager.setBitmap(resource,null,true,WallpaperManager.FLAG_LOCK);
                                                    // Intent intent = new Intent("com.android.camera.action.CROP");
                                                    // intent.setType("image/*");
                                                    // Toast.makeText(this, "Wallpaper set!", Toast.LENGTH_SHORT).show();
//                                                    Intent wall_intent =  new Intent(Intent.ACTION_ATTACH_DATA);
//                                                    wall_intent.setDataAndType(Uri.parse(url), "image/*");
//                                                    wall_intent.putExtra("mimeType", "image/*");
//                                                    Intent chooserIntent = Intent.createChooser(wall_intent,
//                                                            "Set As");
//                                                    chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
//                                                    chooserIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                                    result.success(true);
//                                                    try {
//                                                        getApplicationContext().startActivity(chooserIntent);
//                                                    }catch (Exception e)
//                                                    {
//                                                        e.printStackTrace();
//                                                    }
                                                } catch (IOException ex) {
                                                    ex.printStackTrace();
                                                }
                                            }
                                            @Override
                                            public void onLoadCleared(@Nullable Drawable placeholder) {
                                            }
                                        });

                            } else if (call.method.equals("set_wallpaper")){

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