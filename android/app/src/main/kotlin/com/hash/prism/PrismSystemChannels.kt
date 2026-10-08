package com.hash.prism

import android.app.Activity
import android.app.StatusBarManager
import android.content.ComponentName
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class PrismQuickSettings(private val activity: Activity) {
    private class Tile(val service: Class<*>, val label: Int, val icon: Int)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "requestAddTile" -> requestAddTile(call.arguments as? String, result)
            "refreshWotdWidget" -> {
                WotdWidgetProvider.refresh(activity.applicationContext)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestAddTile(name: String?, result: MethodChannel.Result) {
        val tile = when (name) {
            "shuffle" -> Tile(MyTileService::class.java, R.string.quick_settings, R.drawable.ic_tile_shuffle)
            "wotd" -> Tile(WotdTileService::class.java, R.string.quick_settings_wotd, R.drawable.ic_tile_wotd)
            "favs" -> Tile(FavsTileService::class.java, R.string.quick_settings_favs, R.drawable.ic_tile_favs)
            else -> return result.error("INVALID_TILE", "Unknown tile", null)
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return result.success(-1)
        activity.getSystemService(StatusBarManager::class.java).requestAddTileService(
            ComponentName(activity, tile.service),
            activity.getString(tile.label),
            Icon.createWithResource(activity, tile.icon),
            activity.mainExecutor,
        ) { code -> result.success(code) }
    }
}

internal class PrismSystemColors(private val activity: Activity) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "accent") return result.notImplemented()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return result.success(mapOf("light" to null, "dark" to null))
        result.success(
            mapOf(
                "light" to activity.getColor(android.R.color.system_accent1_600),
                "dark" to activity.getColor(android.R.color.system_accent1_200),
            ),
        )
    }
}
