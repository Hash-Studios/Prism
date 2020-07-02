package com.hash.prism;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import android.annotation.SuppressLint;
import android.content.Context;

import com.bumptech.glide.request.target.CustomTarget;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.app.WallpaperManager;
import android.graphics.Bitmap;
import android.graphics.drawable.Drawable;
import android.os.AsyncTask;
import android.os.Build;
import android.util.Log;
import android.util.Pair;

import com.bumptech.glide.Glide;
import com.bumptech.glide.request.transition.Transition;

import java.io.IOException;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "flutter.prism.set_wallpaper";
    public static  MethodChannel.Result res;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {

                            res = result;
                            if (call.method.equals("set_lock_wallpaper")){

                                String url = call.argument("url"); // .argument returns the correct type
                                android.util.Log.i("Arguments ", "configureFlutterEngine: "+url);

                                Glide.with(getActivity())
                                        .asBitmap()
                                        .load(url)
                                        .into(new CustomTarget<Bitmap>() {
                                            @Override
                                            public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                                Log.i("Arguments ", "configureFlutterEngine: "+"Ready 1");
                                                SetWallPaperTask setWallPaperTask = new SetWallPaperTask(getActivity());
                                                setWallPaperTask.execute(new Pair(resource,"1"));
//                                                WallpaperManager wallpaperManager = WallpaperManager.getInstance(getApplicationContext());
//                                                try {
//                                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
//                                                        wallpaperManager.setBitmap(resource,null,true,WallpaperManager.FLAG_LOCK);
//                                                    }
//                                                    // Intent intent = new Intent("com.android.camera.action.CROP");
//                                                    // intent.setType("image/*");
//                                                    // Toast.makeText(this, "Wallpaper set!", Toast.LENGTH_SHORT).show();
////                                                    Intent wall_intent =  new Intent(Intent.ACTION_ATTACH_DATA);
////                                                    wall_intent.setDataAndType(Uri.parse(url), "image/*");
////                                                    wall_intent.putExtra("mimeType", "image/*");
////                                                    Intent chooserIntent = Intent.createChooser(wall_intent,
////                                                            "Set As");
////                                                    chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
////                                                    chooserIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
//                                                    result.success(true);
////                                                    try {
////                                                        getApplicationContext().startActivity(chooserIntent);
////                                                    }catch (Exception e)
////                                                    {
////                                                        e.printStackTrace();
////                                                    }
//                                                } catch (IOException ex) {
//                                                    ex.printStackTrace();
//                                                }
                                            }
                                            @Override
                                            public void onLoadCleared(@Nullable Drawable placeholder) {
                                            }
                                        });

                            } else if (call.method.equals("set_home_wallpaper")){

                                String url = call.argument("url"); // .argument returns the correct type
                                android.util.Log.i("Arguments ", "configureFlutterEngine: "+url);

                                Glide.with(getActivity())
                                        .asBitmap()
                                        .load(url)
                                        .into(new CustomTarget<Bitmap>() {
                                            @Override
                                            public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                                android.util.Log.i("Arguments ", "configureFlutterEngine: "+"Ready");
                                                SetWallPaperTask setWallPaperTask = new SetWallPaperTask(getActivity());
                                                setWallPaperTask.execute(new Pair  (resource,"2"));
//                                                WallpaperManager wallpaperManager = WallpaperManager.getInstance(getApplicationContext());
//                                                try {
//                                                    wallpaperManager.setBitmap(resource,null,true,WallpaperManager.FLAG_SYSTEM);
//                                                    result.success(true);
//                                                } catch (IOException ex) {
//                                                    ex.printStackTrace();
//                                                }
                                            }
                                            @Override
                                            public void onLoadCleared(@Nullable Drawable placeholder) {
                                            }
                                        });

                            }else if (call.method.equals("set_wallpaper")){

                                String url = call.argument("url"); // .argument returns the correct type
                                android.util.Log.i("Arguments ", "configureFlutterEngine: "+url);

                                Glide.with(getActivity())
                                        .asBitmap()
                                        .load(url)
                                        .into(new CustomTarget<Bitmap>() {
                                            @Override
                                            public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                                android.util.Log.i("Arguments ", "configureFlutterEngine: "+"Ready");
                                                SetWallPaperTask setWallPaperTask = new SetWallPaperTask(getActivity());
                                                setWallPaperTask.execute(new Pair(resource,"3"));
//                                                WallpaperManager wallpaperManager = WallpaperManager.getInstance(getApplicationContext());
//                                                try {
//                                                    wallpaperManager.setBitmap(resource);
//                                                    result.success(true);
//                                                } catch (IOException ex) {
//                                                    ex.printStackTrace();
//                                                }
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

class SetWallPaperTask extends AsyncTask<Pair<Bitmap,String>,Boolean,Boolean>{

    private final Context mContext;
    public SetWallPaperTask(final Context context) {
        mContext = context;
    }

    @Override
    protected final Boolean doInBackground(Pair<Bitmap, String>... pairs) {
        switch (pairs[0].second) {
            case "1": {
                WallpaperManager wallpaperManager = WallpaperManager.getInstance(mContext);
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        wallpaperManager.setBitmap(pairs[0].first, null, true, WallpaperManager.FLAG_LOCK);
                    }
                } catch (IOException ex) {
                    ex.printStackTrace();
                    return false;
                }
                break;
            }
            case "2": {
                WallpaperManager wallpaperManager = WallpaperManager.getInstance(mContext);
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        wallpaperManager.setBitmap(pairs[0].first, null, true, WallpaperManager.FLAG_SYSTEM);
                    }
                } catch (IOException ex) {
                    ex.printStackTrace();
                    return false;
                }
                break;
            }
            case "3": {
                WallpaperManager wallpaperManager = WallpaperManager.getInstance(mContext);
                try {
                    wallpaperManager.setBitmap(pairs[0].first);
                } catch (IOException ex) {
                    ex.printStackTrace();
                    return false;
                }
                break;
            }
        }

        return true;
    }

    @Override
    protected void onCancelled() {
        super.onCancelled();
    }

    @Override
    protected void onPostExecute(Boolean aBoolean) {
        myMethod(aBoolean);
    }

    private void myMethod(Boolean result) {
        MainActivity.res.success(result);
    }
}