package com.hash.prism;

import android.Manifest;
import android.app.Activity;
import android.app.PendingIntent;
import android.app.WallpaperManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.Environment;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;
import android.util.Log;
import android.widget.RemoteViews;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Random;

@RequiresApi(api = Build.VERSION_CODES.N)
public class MyTileService extends TileService {
    private static final String LOG = "Prism::";
    static String path;
    static File directory;
    static File[] files;
    static File[] filesFinal;
    static Context context;
    private static final int requestCode = 101;

    static final String tapAction = "PrismCLICKED";
    public static long getFolderSize(File file) {
        long size = 0;
        if (file.isDirectory()) {
            for (File child : file.listFiles()) {
                size += getFolderSize(child);
            }
        } else {
            size = file.length();
        }
        return size;
    }
    public void setWallpaper(Context context){
        String permission = Manifest.permission.READ_EXTERNAL_STORAGE;
        if (ContextCompat.checkSelfPermission(context, permission)
                == PackageManager.PERMISSION_DENIED) {
            Toast.makeText(context,
                    "Storage permission denied!",
                    Toast.LENGTH_SHORT)
                    .show();
            // Requesting the permission
//            ActivityCompat.requestPermissions(,
//                    new String[] { permission },
//                    requestCode);
        }
        else {
            Tile qsTile = getQsTile();
            qsTile.setState(2);
            qsTile.updateTile();
            Log.d(LOG, "onReceive: " + "clicked");

            // if (files == null || files.length == 0) {
                if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q){
                    path = Environment.getExternalStorageDirectory().toString() + "/Pictures/Prism";
                } else{
                    path = Environment.getExternalStorageDirectory().toString() + "/Prism";
                }
                directory = new File(path);
                files = directory.listFiles();
                int count = 0;
                if(files!=null){
                    count = files.length;
                }
                for (int fileIndex = 0; fileIndex < count; fileIndex++) {
                    long size = getFolderSize(files[fileIndex]) / 1048576;
                    if (size >= 5) {
                        System.arraycopy(files, fileIndex + 1, files, fileIndex, count - fileIndex - 1);
                    }
                }
            // }
            int random = 0;
            if(count!=0){
                random = new Random().nextInt(count);
            }

            Bitmap bitmap;
            try {
                try{
                    File f = files[random];
                    BitmapFactory.Options options = new BitmapFactory.Options();
                    options.inPreferredConfig = Bitmap.Config.ARGB_8888;
                    bitmap = BitmapFactory.decodeStream(new FileInputStream(f), null, options);
                    WallpaperManager wallpaperManager = WallpaperManager.getInstance(context);
                    try {
                        wallpaperManager.setBitmap(bitmap, null, false,
                                WallpaperManager.FLAG_LOCK | WallpaperManager.FLAG_SYSTEM);
                        Log.d("TAG", "onBitmapLoaded: " + (bitmap == null));
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                bitmap.recycle();
                } catch (Exception e) {
                    e.printStackTrace();
                    Toast.makeText(this,
                    "No wallpapers downloaded!",
                    Toast.LENGTH_SHORT)
                    .show();
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
            qsTile.setState(1);
            qsTile.updateTile();
        }

    }
    @Override
    public void onClick() {
        super.onClick();
        context = getApplicationContext();
        setWallpaper(context);
    }

    @Override
    public void onTileAdded() {
        super.onTileAdded();
        Tile qsTile = getQsTile();
        String permission = Manifest.permission.READ_EXTERNAL_STORAGE;
        if (ContextCompat.checkSelfPermission(this, permission)
                == PackageManager.PERMISSION_DENIED) {
            Toast.makeText(this,
                    "Storage permission denied!",
                    Toast.LENGTH_SHORT)
                    .show();
            // Requesting the permission
//            ActivityCompat.requestPermissions(,
//                    new String[] { permission },
//                    requestCode);
            qsTile.setState(0);
            qsTile.updateTile();
        }else {
            qsTile.setState(1);
            qsTile.updateTile();
        }
    }

    @Override
    public void onTileRemoved() {
        super.onTileRemoved();
    }

    @Override
    public void onStartListening() {
        super.onStartListening();
    }

    @Override
    public void onStopListening() {
        super.onStopListening();
    }
}
