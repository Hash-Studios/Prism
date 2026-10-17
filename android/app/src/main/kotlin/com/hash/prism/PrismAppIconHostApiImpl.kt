package com.hash.prism

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import com.hash.prism.pigeon.PrismAppIconHostApi

/**
 * Switches the launcher icon. MainActivity is the default icon; each alternate icon is an activity-alias
 * from the manifest. Exactly one launcher component is enabled at a time.
 */
internal class PrismAppIconHostApiImpl(context: Context) : PrismAppIconHostApi {
    private val context = context.applicationContext

    override fun setAppIcon(iconName: String?, callback: (Result<Boolean>) -> Unit) {
        val target = iconName?.let { ALIASES[it] }
        if (iconName != null && target == null) {
            callback(Result.success(false))
            return
        }
        try {
            if (target == null) {
                setState(MAIN_ACTIVITY, PackageManager.COMPONENT_ENABLED_STATE_DEFAULT)
                ALIASES.values.forEach { setState(it, PackageManager.COMPONENT_ENABLED_STATE_DISABLED) }
            } else {
                setState(target, PackageManager.COMPONENT_ENABLED_STATE_ENABLED)
                setState(MAIN_ACTIVITY, PackageManager.COMPONENT_ENABLED_STATE_DISABLED)
                ALIASES.values.filter { it != target }.forEach { setState(it, PackageManager.COMPONENT_ENABLED_STATE_DISABLED) }
            }
            callback(Result.success(true))
        } catch (error: Exception) {
            callback(Result.success(false))
        }
    }

    override fun currentAppIcon(): String? = ALIASES.entries.firstOrNull { (_, alias) ->
        context.packageManager.getComponentEnabledSetting(component(alias)) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    }?.key

    override fun supportsAlternateIcons(): Boolean = true

    private fun component(name: String) = ComponentName(context, "com.hash.prism.$name")

    private fun setState(name: String, state: Int) {
        context.packageManager.setComponentEnabledSetting(component(name), state, PackageManager.DONT_KILL_APP)
    }

    private companion object {
        const val MAIN_ACTIVITY = "MainActivity"
        val ALIASES = mapOf(
            "AppIconNoir" to "IconNoir",
            "AppIconGlass" to "IconGlass",
            "AppIconSunset" to "IconSunset",
            "AppIconMono" to "IconMono",
        )
    }
}
