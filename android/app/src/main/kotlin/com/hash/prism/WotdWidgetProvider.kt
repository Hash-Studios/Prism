package com.hash.prism

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.util.concurrent.Executors

internal fun widgetSampleSize(width: Int, height: Int, maxPixels: Long = 1_000_000L): Int {
    var sample = 1
    while ((width.toLong() / sample) * (height.toLong() / sample) > maxPixels) sample *= 2
    return sample
}

internal class WotdWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val pending = goAsync()
        val app = context.applicationContext
        executor.execute {
            try {
                val url = app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .getString("flutter.quick_tile.wotd.url", null)?.trim()
                val bitmap = if (url.isNullOrEmpty()) null else loadBitmap(app, url)
                appWidgetIds.forEach { manager.updateAppWidget(it, views(app, bitmap)) }
            } catch (error: Throwable) {
                Log.w("PrismWidget", "Could not update widget", error)
            } finally {
                pending.finish()
            }
        }
    }

    private fun loadBitmap(context: Context, url: String): Bitmap? {
        val file = File.createTempFile("prism-widget-", ".tmp", context.cacheDir)
        try {
            PrismImageTransfer.download(url, file)
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            val options = BitmapFactory.Options().apply { inSampleSize = widgetSampleSize(bounds.outWidth, bounds.outHeight) }
            return BitmapFactory.decodeFile(file.path, options)
        } finally {
            file.delete()
        }
    }

    private fun views(context: Context, bitmap: Bitmap?): RemoteViews = RemoteViews(context.packageName, R.layout.wotd_widget).apply {
        if (bitmap != null) setImageViewBitmap(R.id.wotd_image, bitmap)
        val shown = if (bitmap != null) View.VISIBLE else View.GONE
        val placeholder = if (bitmap != null) View.GONE else View.VISIBLE
        setViewVisibility(R.id.wotd_image, shown)
        setViewVisibility(R.id.wotd_logo, placeholder)
        setViewVisibility(R.id.wotd_hint, placeholder)
        val launch = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        setOnClickPendingIntent(R.id.wotd_root, PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
    }

    companion object {
        private val executor = Executors.newSingleThreadExecutor()

        fun refresh(context: Context) {
            val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, WotdWidgetProvider::class.java))
            if (ids.isEmpty()) return
            context.sendBroadcast(
                Intent(context, WotdWidgetProvider::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }
}
