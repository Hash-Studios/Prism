package com.hash.prism

import android.app.UiModeManager
import org.junit.Assert.assertEquals
import org.junit.Test

internal class LaunchNightModeTest {
    @Test internal fun inAppThemeModeMapsToTheAppNightMode() {
        assertEquals(UiModeManager.MODE_NIGHT_NO, launchNightMode("light"))
        assertEquals(UiModeManager.MODE_NIGHT_YES, launchNightMode("dark"))
        assertEquals(UiModeManager.MODE_NIGHT_AUTO, launchNightMode("system"))
        assertEquals(UiModeManager.MODE_NIGHT_AUTO, launchNightMode(null))
    }
}
