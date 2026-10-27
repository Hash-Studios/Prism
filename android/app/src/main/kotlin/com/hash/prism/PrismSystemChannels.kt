package com.hash.prism

import android.app.Activity
import android.app.StatusBarManager
import android.content.ComponentName
import android.graphics.drawable.Icon
import android.os.Build
import androidx.annotation.RequiresApi
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
        when (call.method) {
            "accent" -> accent(result)
            "scheme" -> try {
                result.success(scheme())
            } catch (e: Exception) {
                result.error("SCHEME_READ_FAILED", e.message, null)
            }
            else -> result.notImplemented()
        }
    }

    private fun accent(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return result.success(mapOf("light" to null, "dark" to null))
        result.success(
            mapOf(
                "light" to activity.getColor(android.R.color.system_accent1_600),
                "dark" to activity.getColor(android.R.color.system_accent1_200),
            ),
        )
    }

    private fun scheme(): Map<String, Map<String, Int>>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return apiSchemeRoles()
        val palettes = shadePalettes()
        return mapOf(
            "light" to MaterialYouScheme.fromPalettes(palettes, dark = false),
            "dark" to MaterialYouScheme.fromPalettes(palettes, dark = true),
        )
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun shadePalettes(): MaterialYouScheme.Palettes {
        return MaterialYouScheme.Palettes(
            accent1 = shades(
                android.R.color.system_accent1_0, android.R.color.system_accent1_10, android.R.color.system_accent1_50,
                android.R.color.system_accent1_100, android.R.color.system_accent1_200, android.R.color.system_accent1_300,
                android.R.color.system_accent1_400, android.R.color.system_accent1_500, android.R.color.system_accent1_600,
                android.R.color.system_accent1_700, android.R.color.system_accent1_800, android.R.color.system_accent1_900,
                android.R.color.system_accent1_1000,
            ),
            accent2 = shades(
                android.R.color.system_accent2_0, android.R.color.system_accent2_10, android.R.color.system_accent2_50,
                android.R.color.system_accent2_100, android.R.color.system_accent2_200, android.R.color.system_accent2_300,
                android.R.color.system_accent2_400, android.R.color.system_accent2_500, android.R.color.system_accent2_600,
                android.R.color.system_accent2_700, android.R.color.system_accent2_800, android.R.color.system_accent2_900,
                android.R.color.system_accent2_1000,
            ),
            accent3 = shades(
                android.R.color.system_accent3_0, android.R.color.system_accent3_10, android.R.color.system_accent3_50,
                android.R.color.system_accent3_100, android.R.color.system_accent3_200, android.R.color.system_accent3_300,
                android.R.color.system_accent3_400, android.R.color.system_accent3_500, android.R.color.system_accent3_600,
                android.R.color.system_accent3_700, android.R.color.system_accent3_800, android.R.color.system_accent3_900,
                android.R.color.system_accent3_1000,
            ),
            neutral1 = shades(
                android.R.color.system_neutral1_0, android.R.color.system_neutral1_10, android.R.color.system_neutral1_50,
                android.R.color.system_neutral1_100, android.R.color.system_neutral1_200, android.R.color.system_neutral1_300,
                android.R.color.system_neutral1_400, android.R.color.system_neutral1_500, android.R.color.system_neutral1_600,
                android.R.color.system_neutral1_700, android.R.color.system_neutral1_800, android.R.color.system_neutral1_900,
                android.R.color.system_neutral1_1000,
            ),
            neutral2 = shades(
                android.R.color.system_neutral2_0, android.R.color.system_neutral2_10, android.R.color.system_neutral2_50,
                android.R.color.system_neutral2_100, android.R.color.system_neutral2_200, android.R.color.system_neutral2_300,
                android.R.color.system_neutral2_400, android.R.color.system_neutral2_500, android.R.color.system_neutral2_600,
                android.R.color.system_neutral2_700, android.R.color.system_neutral2_800, android.R.color.system_neutral2_900,
                android.R.color.system_neutral2_1000,
            ),
        )
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun shades(vararg ids: Int): IntArray = IntArray(ids.size) { activity.getColor(ids[it]) }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun apiSchemeRoles(): Map<String, Map<String, Int>> {
        val fixed = linkedMapOf(
            "primaryFixed" to activity.getColor(android.R.color.system_primary_fixed),
            "primaryFixedDim" to activity.getColor(android.R.color.system_primary_fixed_dim),
            "onPrimaryFixed" to activity.getColor(android.R.color.system_on_primary_fixed),
            "onPrimaryFixedVariant" to activity.getColor(android.R.color.system_on_primary_fixed_variant),
            "secondaryFixed" to activity.getColor(android.R.color.system_secondary_fixed),
            "secondaryFixedDim" to activity.getColor(android.R.color.system_secondary_fixed_dim),
            "onSecondaryFixed" to activity.getColor(android.R.color.system_on_secondary_fixed),
            "onSecondaryFixedVariant" to activity.getColor(android.R.color.system_on_secondary_fixed_variant),
            "tertiaryFixed" to activity.getColor(android.R.color.system_tertiary_fixed),
            "tertiaryFixedDim" to activity.getColor(android.R.color.system_tertiary_fixed_dim),
            "onTertiaryFixed" to activity.getColor(android.R.color.system_on_tertiary_fixed),
            "onTertiaryFixedVariant" to activity.getColor(android.R.color.system_on_tertiary_fixed_variant),
            "shadow" to 0xFF000000.toInt(),
            "scrim" to 0xFF000000.toInt(),
        )
        val light = linkedMapOf(
            "primary" to activity.getColor(android.R.color.system_primary_light),
            "onPrimary" to activity.getColor(android.R.color.system_on_primary_light),
            "primaryContainer" to activity.getColor(android.R.color.system_primary_container_light),
            "onPrimaryContainer" to activity.getColor(android.R.color.system_on_primary_container_light),
            "secondary" to activity.getColor(android.R.color.system_secondary_light),
            "onSecondary" to activity.getColor(android.R.color.system_on_secondary_light),
            "secondaryContainer" to activity.getColor(android.R.color.system_secondary_container_light),
            "onSecondaryContainer" to activity.getColor(android.R.color.system_on_secondary_container_light),
            "tertiary" to activity.getColor(android.R.color.system_tertiary_light),
            "onTertiary" to activity.getColor(android.R.color.system_on_tertiary_light),
            "tertiaryContainer" to activity.getColor(android.R.color.system_tertiary_container_light),
            "onTertiaryContainer" to activity.getColor(android.R.color.system_on_tertiary_container_light),
            "error" to activity.getColor(android.R.color.system_error_light),
            "onError" to activity.getColor(android.R.color.system_on_error_light),
            "errorContainer" to activity.getColor(android.R.color.system_error_container_light),
            "onErrorContainer" to activity.getColor(android.R.color.system_on_error_container_light),
            "surface" to activity.getColor(android.R.color.system_surface_light),
            "onSurface" to activity.getColor(android.R.color.system_on_surface_light),
            "surfaceDim" to activity.getColor(android.R.color.system_surface_dim_light),
            "surfaceBright" to activity.getColor(android.R.color.system_surface_bright_light),
            "surfaceContainerLowest" to activity.getColor(android.R.color.system_surface_container_lowest_light),
            "surfaceContainerLow" to activity.getColor(android.R.color.system_surface_container_low_light),
            "surfaceContainer" to activity.getColor(android.R.color.system_surface_container_light),
            "surfaceContainerHigh" to activity.getColor(android.R.color.system_surface_container_high_light),
            "surfaceContainerHighest" to activity.getColor(android.R.color.system_surface_container_highest_light),
            "onSurfaceVariant" to activity.getColor(android.R.color.system_on_surface_variant_light),
            "outline" to activity.getColor(android.R.color.system_outline_light),
            "outlineVariant" to activity.getColor(android.R.color.system_outline_variant_light),
            "inverseSurface" to activity.getColor(android.R.color.system_neutral1_800),
            "onInverseSurface" to activity.getColor(android.R.color.system_neutral1_50),
            "inversePrimary" to activity.getColor(android.R.color.system_accent1_200),
        )
        val dark = linkedMapOf(
            "primary" to activity.getColor(android.R.color.system_primary_dark),
            "onPrimary" to activity.getColor(android.R.color.system_on_primary_dark),
            "primaryContainer" to activity.getColor(android.R.color.system_primary_container_dark),
            "onPrimaryContainer" to activity.getColor(android.R.color.system_on_primary_container_dark),
            "secondary" to activity.getColor(android.R.color.system_secondary_dark),
            "onSecondary" to activity.getColor(android.R.color.system_on_secondary_dark),
            "secondaryContainer" to activity.getColor(android.R.color.system_secondary_container_dark),
            "onSecondaryContainer" to activity.getColor(android.R.color.system_on_secondary_container_dark),
            "tertiary" to activity.getColor(android.R.color.system_tertiary_dark),
            "onTertiary" to activity.getColor(android.R.color.system_on_tertiary_dark),
            "tertiaryContainer" to activity.getColor(android.R.color.system_tertiary_container_dark),
            "onTertiaryContainer" to activity.getColor(android.R.color.system_on_tertiary_container_dark),
            "error" to activity.getColor(android.R.color.system_error_dark),
            "onError" to activity.getColor(android.R.color.system_on_error_dark),
            "errorContainer" to activity.getColor(android.R.color.system_error_container_dark),
            "onErrorContainer" to activity.getColor(android.R.color.system_on_error_container_dark),
            "surface" to activity.getColor(android.R.color.system_surface_dark),
            "onSurface" to activity.getColor(android.R.color.system_on_surface_dark),
            "surfaceDim" to activity.getColor(android.R.color.system_surface_dim_dark),
            "surfaceBright" to activity.getColor(android.R.color.system_surface_bright_dark),
            "surfaceContainerLowest" to activity.getColor(android.R.color.system_surface_container_lowest_dark),
            "surfaceContainerLow" to activity.getColor(android.R.color.system_surface_container_low_dark),
            "surfaceContainer" to activity.getColor(android.R.color.system_surface_container_dark),
            "surfaceContainerHigh" to activity.getColor(android.R.color.system_surface_container_high_dark),
            "surfaceContainerHighest" to activity.getColor(android.R.color.system_surface_container_highest_dark),
            "onSurfaceVariant" to activity.getColor(android.R.color.system_on_surface_variant_dark),
            "outline" to activity.getColor(android.R.color.system_outline_dark),
            "outlineVariant" to activity.getColor(android.R.color.system_outline_variant_dark),
            "inverseSurface" to activity.getColor(android.R.color.system_neutral1_100),
            "onInverseSurface" to activity.getColor(android.R.color.system_neutral1_800),
            "inversePrimary" to activity.getColor(android.R.color.system_accent1_600),
        )
        return mapOf(
            "light" to light + fixed + ("surfaceTint" to light.getValue("primary")),
            "dark" to dark + fixed + ("surfaceTint" to dark.getValue("primary")),
        )
    }
}
