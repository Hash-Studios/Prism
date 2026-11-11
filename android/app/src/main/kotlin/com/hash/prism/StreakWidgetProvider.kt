package com.hash.prism

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/** Home screen streak widget. It reads only the snapshot the app writes, and redraws at the streak's local midnight. */
internal class StreakWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_MIDNIGHT) refresh(context) else super.onReceive(context, intent)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val snapshot = load(context)
        val display = streakDisplay(snapshot, System.currentTimeMillis())
        appWidgetIds.forEach { manager.updateAppWidget(it, views(context, display, sizeOf(manager, it))) }
        scheduleMidnight(context, snapshot, display)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        val display = streakDisplay(load(context), System.currentTimeMillis())
        manager.updateAppWidget(appWidgetId, views(context, display, sizeOf(newOptions)))
    }

    override fun onDisabled(context: Context) {
        alarmManager(context).cancel(midnightIntent(context))
    }

    private fun sizeOf(manager: AppWidgetManager, widgetId: Int): StreakWidgetSize = sizeOf(manager.getAppWidgetOptions(widgetId))

    private fun sizeOf(options: Bundle): StreakWidgetSize = streakWidgetSize(
        options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH),
        options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT),
    )

    private fun views(context: Context, display: StreakDisplay?, size: StreakWidgetSize): RemoteViews {
        if (display == null) {
            return RemoteViews(context.packageName, R.layout.streak_widget_signed_out).apply {
                setOnClickPendingIntent(R.id.streak_root, openApp(context, null))
            }
        }
        val layout = if (size == StreakWidgetSize.LARGE) R.layout.streak_widget_large else R.layout.streak_widget_compact
        val description = if (display.keptToday) R.plurals.streak_widget_kept_description else R.plurals.streak_widget_open_description
        return RemoteViews(context.packageName, layout).apply {
            setTextViewText(R.id.streak_count, display.count.toString())
            setInt(R.id.streak_ring, "setBackgroundResource", if (display.keptToday) R.drawable.streak_ring_full else R.drawable.streak_ring_track)
            setContentDescription(R.id.streak_root, context.resources.getQuantityString(description, display.count, display.count))
            if (size == StreakWidgetSize.LARGE) {
                val status = when {
                    display.keptToday -> R.string.streak_widget_kept
                    display.count == 0 -> R.string.streak_widget_start
                    else -> R.string.streak_widget_keep
                }
                setTextViewText(R.id.streak_status, context.getString(status))
                setViewVisibility(R.id.streak_status, View.VISIBLE)
            }
            setOnClickPendingIntent(R.id.streak_root, openApp(context, STREAK_WIDGET_LINK))
        }
    }

    private fun openApp(context: Context, link: String?): PendingIntent {
        val launch = (context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent(context, MainActivity::class.java))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (link != null) {
            launch.action = Intent.ACTION_VIEW
            launch.data = Uri.parse(link)
        }
        return PendingIntent.getActivity(context, REQUEST_OPEN, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun scheduleMidnight(context: Context, snapshot: StreakSnapshot?, display: StreakDisplay?) {
        val alarms = alarmManager(context)
        val pending = midnightIntent(context)
        // Signed out or lapsed: nothing changes at midnight until the app writes a new snapshot.
        if (snapshot == null || display == null || display.count == 0) {
            alarms.cancel(pending)
            return
        }
        // RTC, not RTC_WAKEUP: a sleeping phone is not woken. The widget redraws when the phone next wakes.
        val at = nextStreakMidnight(System.currentTimeMillis(), snapshot.utcOffsetMinutes) + MIDNIGHT_MARGIN_MS
        alarms.setWindow(AlarmManager.RTC, at, MIDNIGHT_WINDOW_MS, pending)
    }

    companion object {
        private const val ACTION_MIDNIGHT = "com.hash.prism.action.STREAK_WIDGET_MIDNIGHT"
        private const val PREFS = "prism_streak_widget"
        private const val KEY_COUNT = "count"
        private const val KEY_LAST_KEPT_DAY = "last_kept_day"
        private const val KEY_UTC_OFFSET = "utc_offset_minutes"
        private const val KEY_FREEZES = "freezes"
        private const val REQUEST_OPEN = 0
        private const val REQUEST_MIDNIGHT = 1
        private const val MIDNIGHT_MARGIN_MS = 1_000L
        private const val MIDNIGHT_WINDOW_MS = 60_000L

        fun save(context: Context, snapshot: StreakSnapshot?) {
            val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear()
            snapshot?.let {
                editor.putInt(KEY_COUNT, it.count)
                    .putString(KEY_LAST_KEPT_DAY, it.lastKeptDay)
                    .putInt(KEY_UTC_OFFSET, it.utcOffsetMinutes)
                    .putInt(KEY_FREEZES, it.freezes)
            }
            editor.commit()
            refresh(context)
        }

        fun load(context: Context): StreakSnapshot? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val lastKeptDay = prefs.getString(KEY_LAST_KEPT_DAY, null) ?: return null
            return StreakSnapshot(prefs.getInt(KEY_COUNT, 0), lastKeptDay, prefs.getInt(KEY_UTC_OFFSET, 0), prefs.getInt(KEY_FREEZES, 0))
        }

        fun refresh(context: Context) {
            val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, StreakWidgetProvider::class.java))
            if (ids.isEmpty()) return
            context.sendBroadcast(
                Intent(context, StreakWidgetProvider::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }

        private fun alarmManager(context: Context): AlarmManager = context.getSystemService(AlarmManager::class.java)

        private fun midnightIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_MIDNIGHT,
            Intent(context, StreakWidgetProvider::class.java).setAction(ACTION_MIDNIGHT),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
