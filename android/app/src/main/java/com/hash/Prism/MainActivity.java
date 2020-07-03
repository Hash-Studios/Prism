package com.hash.prism;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.FileProvider;
import android.annotation.SuppressLint;
import android.content.ActivityNotFoundException;
import android.content.Context;

import com.bumptech.glide.request.target.CustomTarget;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.app.WallpaperManager;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Log;
import android.util.Pair;
import android.widget.Toast;
import com.bumptech.glide.Glide;
import com.bumptech.glide.request.transition.Transition;
import com.theartofdev.edmodo.cropper.CropImage;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "flutter.prism.set_wallpaper";
    public static MethodChannel.Result res;
    private static int METHOD = -1;
    private static Uri URI = null;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {

                            res = result;

                            switch (call.method) {
                                case "set_lock_wallpaper": {
                                    METHOD = 1;
                                    String url = call.argument("url"); // .argument returns the correct type

                                    Log.i("Arguments ", "configureFlutterEngine: " + url);
                                    Glide.with(getActivity())
                                            .asBitmap()
                                            .load(url)
                                            .into(new CustomTarget<Bitmap>() {
                                                @Override
                                                public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                                    Log.i("Arguments ", "configureFlutterEngine: " + "Ready 1");
//                                                SetWallPaperTask setWallPaperTask = new SetWallPaperTask(getActivity());
//                                                setWallPaperTask.execute(new Pair(resource,"1"));
                                                    saveImage(resource);
                                                }

                                                @Override
                                                public void onLoadCleared(@Nullable Drawable placeholder) {
                                                }
                                            });

                                    break;
                                }
                                case "set_home_wallpaper": {
                                    METHOD = 2;
                                    String url = call.argument("url"); // .argument returns the correct type

                                    Log.i("Arguments ", "configureFlutterEngine: " + url);
                                    Glide.with(getActivity())
                                            .asBitmap()
                                            .load(url)
                                            .into(new CustomTarget<Bitmap>() {
                                                @Override
                                                public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                                    Log.i("Arguments ", "configureFlutterEngine: " + "Ready");
//                                                SetWallPaperTask setWallPaperTask = new SetWallPaperTask(getActivity());
//                                                setWallPaperTask.execute(new Pair  (resource,"2"));
                                                    saveImage(resource);
                                                }

                                                @Override
                                                public void onLoadCleared(@Nullable Drawable placeholder) {
                                                }
                                            });
                                    break;
                                }
                                case "set_wallpaper": {
                                    METHOD = 3;
                                    String url = call.argument("url"); // .argument returns the correct type
                                    Log.i("Arguments ", "configureFlutterEngine: " + url);
                                    Glide.with(getActivity())
                                            .asBitmap()
                                            .load(url)
                                            .into(new CustomTarget<Bitmap>() {
                                                @Override
                                                public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                                                    Log.i("Arguments ", "configureFlutterEngine: " + "Ready");
//                                                SetWallPaperTask setWallPaperTask = new SetWallPaperTask(getActivity());
//                                                setWallPaperTask.execute(new Pair(resource,"3"));
                                                    saveImage(resource);
                                                }

                                                @Override
                                                public void onLoadCleared(@Nullable Drawable placeholder) {
                                                }
                                            });

                                    break;
                                }
                            }
                        }
                );
    }


    private void saveImage(Bitmap image) {
        File pictureFile = getOutputMediaFile();
        if (pictureFile == null) {
            Log.d("Error",
                    "Error creating media file, check storage permissions: ");// e.getMessage());
            return;
        }
        try {
            FileOutputStream fos = new FileOutputStream(pictureFile);
            image.compress(Bitmap.CompressFormat.PNG, 90, fos);
            fos.close();
        } catch (FileNotFoundException e) {
            Log.d("TAG", "File not found: " + e.getMessage());
        } catch (IOException e) {
            Log.d("TAG", "Error accessing file: " + e.getMessage());
        }

        try {
            Uri uri = FileProvider.getUriForFile(this, this.getApplicationContext().getPackageName() + ".provider", pictureFile);
            URI = uri;
            performCrop(uri);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Create a File for saving an image or video
     */
    private File getOutputMediaFile() {

        File mediaStorageDir = new File(Environment.getExternalStorageDirectory()
                + "/Android/data/"
                + getApplicationContext().getPackageName()
                + "/Files");

        if (!mediaStorageDir.exists()) {
            if (!mediaStorageDir.mkdirs()) {
                return null;
            }
        }

        String timeStamp = new SimpleDateFormat("ddMMyyyy_HHmm").format(new Date());
        File mediaFile;
        String mImageName = "MI_" + timeStamp + ".jpg";
        mediaFile = new File(mediaStorageDir.getPath() + File.separator + mImageName);
        Log.i("  ", "getOutputMediaFile: " + mediaFile.getAbsolutePath());
        Log.i("  ", "getOutputMediaFile: " + mediaFile.getPath());
        return mediaFile;
    }


    private void performCrop(Uri uri) {
        CropImage.activity(uri).setInitialCropWindowPaddingRatio(0.0f)
                .start(this);
    }


    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == CropImage.CROP_IMAGE_ACTIVITY_REQUEST_CODE) {
            CropImage.ActivityResult result = CropImage.getActivityResult(data);
            if (resultCode == RESULT_OK) {
                Uri resultUri = result.getUri();
                SetWallPaperTask setWallPaperTask = new SetWallPaperTask(getActivity(), URI);
                try {
                    Bitmap bitmap = MediaStore.Images.Media.getBitmap(this.getContentResolver(), resultUri);
                    if (METHOD == 1)
                        setWallPaperTask.execute(new Pair(bitmap, "1"));
                    else if (METHOD == 2)
                        setWallPaperTask.execute(new Pair(bitmap, "2"));
                    else if (METHOD == 3)
                        setWallPaperTask.execute(new Pair(bitmap, "3"));
                } catch (IOException e) {
                    e.printStackTrace();
                }
            } else if (resultCode == CropImage.CROP_IMAGE_ACTIVITY_RESULT_ERROR_CODE) {
                Exception error = result.getError();
            }
        }
    }
}

class SetWallPaperTask extends AsyncTask<Pair<Bitmap, String>, Boolean, Boolean> {

    private final Context mContext;
    private final Uri uri;

    public SetWallPaperTask(final Context context, Uri URI) {
        mContext = context;
        uri = URI;
    }

    @SafeVarargs
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
                mContext.getContentResolver().delete(uri, null, null);
                Log.i("File", "Deleted " + uri);
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
                mContext.getContentResolver().delete(uri, null, null);
                Log.i("File", "Deleted " + uri);
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
                mContext.getContentResolver().delete(uri, null, null);
                Log.i("File", "Deleted " + uri);
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
