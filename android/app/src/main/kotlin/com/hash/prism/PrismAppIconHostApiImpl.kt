package com.hash.prism

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import com.hash.prism.pigeon.PrismAppIconHostApi

/** Switches the launcher icon by enabling one activity-alias from the manifest and disabling the others. */
internal class PrismAppIconHostApiImpl(context: Context) : PrismAppIconHostApi {
    private val context = context.applicationContext

    override fun setAppIcon(iconName: String?, callback: (Result<Boolean>) -> Unit) {
        val target = if (iconName == null) DEFAULT_ALIAS else ALIASES[iconName]
        if (target == null) {
            callback(Result.success(false))
            return
        }
        try {
            setEnabled(target, true)
            (ALIASES.values + DEFAULT_ALIAS).filter { it != target }.forEach { setEnabled(it, false) }
            callback(Result.success(true))
        } catch (error: Exception) {
            callback(Result.success(false))
        }
    }

    override fun currentAppIcon(): String? = ALIASES.entries.firstOrNull { (_, alias) ->
        context.packageManager.getComponentEnabledSetting(component(alias)) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    }?.key

    override fun supportsAlternateIcons(): Boolean = true

    private fun component(alias: String) = ComponentName(context, "com.hash.prism.$alias")

    private fun setEnabled(alias: String, enabled: Boolean) {
        context.packageManager.setComponentEnabledSetting(
            component(alias),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    private companion object {
        const val DEFAULT_ALIAS = "IconDefault"
        val ALIASES = mapOf(
            "AppIconNoir" to "IconNoir",
            "AppIconGlass" to "IconGlass",
            "AppIconSunset" to "IconSunset",
            "AppIconMono" to "IconMono",
        )
    }
}
