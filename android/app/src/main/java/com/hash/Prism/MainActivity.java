package com.hash.prism;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.annotation.SuppressLint;
import android.content.Context;

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
import android.net.Uri;
import android.content.ContentValues;
import android.content.*;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.provider.MediaStore;

import com.squareup.picasso.Picasso;
import com.squareup.picasso.Target;
import com.squareup.picasso.Callback;
import java.io.*;
import java.io.File;
import java.io.IOException;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "flutter.prism.set_wallpaper";
    public static MethodChannel.Result res;
    private Target target = new Target() {
        @Override
        public void onBitmapLoaded(Bitmap resource, Picasso.LoadedFrom from) {
            android.util.Log.i("Arguments ", "configureFlutterEngine: " + "Ready");
            SetWallPaperTask setWallPaperTask = new SetWallPaperTask(getActivity());
            setWallPaperTask.execute(new Pair(resource, "1"));
        }

        @Override
        public void onBitmapFailed(Exception e, Drawable errorDrawable) {
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
                    if (call.method.equals("set_wallpaper")) {
                        String url = call.argument("url"); // .argument returns the correct type
                        android.util.Log.i("Arguments ", "configureFlutterEngine: " + url);
                        Picasso.get().load(url).into(target);
                        android.util.Log.i("Arguments ", "configureFlutterEngine: " + "Image Downloaded");

                    }
                });
    }
}

class SetWallPaperTask extends AsyncTask<Pair<Bitmap, String>, Boolean, Boolean> {

    private final Context mContext;

    public SetWallPaperTask(final Context context) {
        mContext = context;
    }

    @Override
    protected final Boolean doInBackground(Pair<Bitmap, String>... pairs) {
        WallpaperManager wallpaperManager = WallpaperManager.getInstance(mContext);
        try {
            Uri tempUri = getImageUri(mContext, pairs[0].first);
            android.util.Log.i("Arguments ", "configureFlutterEngine: " + "Saved image to storage");
            File finalFile = new File(getRealPathFromURI(tempUri));
            Uri contentURI = getImageContentUri(mContext, finalFile.getAbsolutePath());
            android.util.Log.i("Arguments ", "configureFlutterEngine: " + "Opening crop intent");
            mContext.startActivity(wallpaperManager.getCropAndSetWallpaperIntent(contentURI));
            // wallpaperManager.setBitmap(pairs[0].first);
        } catch (Exception ex) {
            ex.printStackTrace();
            return false;
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

    public static Uri getImageContentUri(Context context, String absPath) {

        Cursor cursor = context.getContentResolver().query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                new String[] { MediaStore.Images.Media._ID }, MediaStore.Images.Media.DATA + "=? ",
                new String[] { absPath }, null);

        if (cursor != null && cursor.moveToFirst()) {
            int id = cursor.getInt(cursor.getColumnIndex(MediaStore.MediaColumns._ID));
            return Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, Integer.toString(id));

        } else if (!absPath.isEmpty()) {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Images.Media.DATA, absPath);
            return context.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        } else {
            return null;
        }
    }

    public Uri getImageUri(Context inContext, Bitmap inImage) {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        inImage.compress(Bitmap.CompressFormat.JPEG, 100, bytes);
        String path = MediaStore.Images.Media.insertImage(inContext.getContentResolver(), inImage, "Title", null);
        return Uri.parse(path);
    }

    public String getRealPathFromURI(Uri uri) {
        Cursor cursor = mContext.getContentResolver().query(uri, null, null, null, null);
        cursor.moveToFirst();
        int idx = cursor.getColumnIndex(MediaStore.Images.ImageColumns.DATA);
        return cursor.getString(idx);
    }
}