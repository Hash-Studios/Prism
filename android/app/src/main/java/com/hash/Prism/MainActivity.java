package com.hash.prism;

import androidx.annotation.NonNull;

import android.content.Context;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.app.DownloadManager;
import android.app.WallpaperManager;
import android.graphics.Bitmap;
import android.graphics.drawable.Drawable;
import android.os.AsyncTask;
import android.os.Environment;
import android.os.Build;
import android.util.Log;
import android.util.Pair;
import android.net.Uri;
import android.content.ContentValues;
import android.content.*;
import android.database.Cursor;
import android.provider.MediaStore;
import android.view.View;
import android.widget.ImageButton;
import android.widget.TextView;
import android.widget.Toast;

import com.squareup.picasso.Picasso;
import com.squareup.picasso.Target;

import java.io.*;
import java.io.File;
import java.io.IOException;
import java.util.Objects;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "flutter.prism.set_wallpaper";
    public static MethodChannel.Result res;
    
    Target saveImageTarget = new Target() {
        @Override
        public void onBitmapLoaded(Bitmap bitmap, Picasso.LoadedFrom from) {
            try {
                saveImageToPictures(bitmap, "default_" + System.currentTimeMillis());
            } catch (IOException e) {
                e.printStackTrace();
                res.success(false);
            }
        }

        @Override
        public void onBitmapFailed(Exception e, Drawable errorDrawable) {
            res.success(false);
            e.printStackTrace();
        }

        @Override
        public void onPrepareLoad(Drawable placeHolderDrawable) {
        }
    };

    Target saveSetupTarget = new Target() {
        @Override
        public void onBitmapLoaded(Bitmap bitmap, Picasso.LoadedFrom from) {
            try {
                saveImageToPictures(bitmap, "Prism Setups/default_" + System.currentTimeMillis());
            } catch (IOException e) {
                e.printStackTrace();
                res.success(false);
            }
        }

        @Override
        public void onBitmapFailed(Exception e, Drawable errorDrawable) {
            res.success(false);
            e.printStackTrace();
        }

        @Override
        public void onPrepareLoad(Drawable placeHolderDrawable) {
        }
    };


    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    res = result;
                    if (call.method.equals("save_image")) {
                        String link = call.argument("link");
                        Picasso.get().load(link).into(saveImageTarget);
                    } else if (call.method.equals("save_image_file")) {
                        String link = call.argument("link");
                        Picasso.get().load("file://" + link).into(saveImageTarget);
                    } else if (call.method.equals("save_setup")) {
                        String link = call.argument("link");
                        Picasso.get().load(link).into(saveSetupTarget);
                    }
                });
    }

    private void saveImageToPictures(Bitmap bitmap, @NonNull String name) throws IOException {
        OutputStream fos;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContentResolver resolver = getContentResolver();
                ContentValues contentValues = new ContentValues();
                contentValues.put(MediaStore.MediaColumns.DISPLAY_NAME, name + ".jpg");
                contentValues.put(MediaStore.MediaColumns.MIME_TYPE, "image/jpg");
                contentValues.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + File.separator + "Prism");
                Uri imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues);
                fos = resolver.openOutputStream(Objects.requireNonNull(imageUri));
            } else {
                String imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES + File.separator + "Prism").toString();
                File image = new File(imagesDir, name + ".jpg");
                fos = new FileOutputStream(image);
            }
            bitmap.compress(Bitmap.CompressFormat.JPEG, 100, fos);
            Objects.requireNonNull(fos).close();
        } catch (Exception e) {
            e.printStackTrace();
            res.success(false);
        }
        res.success(true);
    }
}