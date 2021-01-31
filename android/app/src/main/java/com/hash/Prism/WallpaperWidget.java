package com.hash.prism;

import android.app.PendingIntent;
import android.app.WallpaperManager;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.Environment;
import android.util.Log;
import android.widget.RemoteViews;

import androidx.annotation.RequiresApi;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Random;

/**
 * Implementation of App Widget functionality.
 */
public class WallpaperWidget extends AppWidgetProvider {

    private static final String LOG = "Prism::";
    static String path;
    static File directory;
    static File[] files;
    static File[] filesFinal;

    static final String clickAction = "PrismCLICKED";
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
    static void updateAppWidget(Context context, AppWidgetManager appWidgetManager,
                                int appWidgetId) {

        // Construct the RemoteViews object
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.wallpaper_widget);

        Intent intent = new Intent(context, WallpaperWidget.class);
        intent.setAction(clickAction);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(context, 0, intent, 0);
        RemoteViews.RemoteResponse remoteResponse = RemoteViews.RemoteResponse.fromPendingIntent(pendingIntent);
        views.setOnClickResponse(R.id.example_refresh_button, remoteResponse);
        // Instruct the widget manager to update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views);
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if (intent.getAction().equals(clickAction)) {
            Log.d(LOG, "onReceive: " + "clicked");

            if(files == null || files.length == 0) {
                path = Environment.getExternalStorageDirectory().toString() + "/Prism";
                directory = new File(path);
                files = directory.listFiles();
                for (int fileIndex = 0; fileIndex < files.length; fileIndex++){
                    long size = getFolderSize(files[fileIndex]) / 1048576;
                    if(size>=5){
                        System.arraycopy(files, fileIndex + 1, files, fileIndex, files.length - fileIndex - 1);
                    }
                }
            }

            int random = new Random().nextInt(files.length);

            Bitmap bitmap;
            try {
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
            }
        
        }
    }

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        // There may be multiple widgets active, so update all of them
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    @Override
    public void onEnabled(Context context) {
        // Enter relevant functionality for when the first widget is created
    }

    @Override
    public void onDisabled(Context context) {
        // Enter relevant functionality for when the last widget is disabled
    }
}