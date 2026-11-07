package com.hash.prism

import android.app.UiModeManager
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.Rule
import org.junit.rules.TemporaryFolder

internal class LaunchNightModeTest {
    @get:Rule val folder = TemporaryFolder()

    @Test internal fun inAppThemeModeMapsToTheAppNightMode() {
        assertEquals(UiModeManager.MODE_NIGHT_NO, launchNightMode("light"))
        assertEquals(UiModeManager.MODE_NIGHT_YES, launchNightMode("dark"))
        assertEquals(UiModeManager.MODE_NIGHT_AUTO, launchNightMode("system"))
    }

    @Test internal fun invalidModesDoNotSilentlyResetTheAppToSystem() {
        for (value in listOf(null, "", "Dark", "unknown")) {
            assertNull(launchNightMode(value))
        }
    }

    @Test internal fun nonStringInputsAreRejected() {
        for (value in listOf(2, true, mapOf("mode" to "dark"))) {
            assertNull(launchNightMode(value))
        }
    }

    @Test internal fun unchangedModeDoesNotApplyOnEveryLaunch() {
        val cache = File(folder.root, "launch_night_mode")
        val applied = mutableListOf<Int>()

        repeat(3) { updateLaunchNightMode(UiModeManager.MODE_NIGHT_YES, cache, null, applied::add) }

        assertEquals(listOf(UiModeManager.MODE_NIGHT_YES), applied)
        assertEquals("2", cache.readText())
    }

    @Test internal fun explicitModeAppliesWhenTheInstallLocalCacheIsMissing() {
        val cache = File(folder.root, "launch_night_mode")
        val applied = mutableListOf<Int>()

        updateLaunchNightMode(UiModeManager.MODE_NIGHT_YES, cache, UiModeManager.MODE_NIGHT_YES, applied::add)

        assertEquals(listOf(UiModeManager.MODE_NIGHT_YES), applied)
        assertEquals("2", cache.readText())
    }

    @Test internal fun initialSystemModeNeedsNoOverride() {
        val cache = File(folder.root, "launch_night_mode")
        val applied = mutableListOf<Int>()

        updateLaunchNightMode(UiModeManager.MODE_NIGHT_AUTO, cache, null, applied::add)
        updateLaunchNightMode(UiModeManager.MODE_NIGHT_YES, cache, null, applied::add)

        assertEquals(listOf(UiModeManager.MODE_NIGHT_YES), applied)
        assertEquals("2", cache.readText())
    }

    @Test internal fun switchingToSystemClearsTheExplicitOverride() {
        val cache = File(folder.root, "launch_night_mode")
        val applied = mutableListOf<Int>()

        updateLaunchNightMode(UiModeManager.MODE_NIGHT_YES, cache, null, applied::add)
        updateLaunchNightMode(UiModeManager.MODE_NIGHT_AUTO, cache, null, applied::add)
        updateLaunchNightMode(UiModeManager.MODE_NIGHT_AUTO, cache, null, applied::add)

        assertEquals(listOf(UiModeManager.MODE_NIGHT_YES, UiModeManager.MODE_NIGHT_AUTO), applied)
        assertEquals("0", cache.readText())
    }

    @Test internal fun legacyExplicitOverrideIsClearedOnFirstSystemSync() {
        val cache = File(folder.root, "launch_night_mode")
        val applied = mutableListOf<Int>()

        updateLaunchNightMode(UiModeManager.MODE_NIGHT_AUTO, cache, UiModeManager.MODE_NIGHT_YES, applied::add)
        updateLaunchNightMode(UiModeManager.MODE_NIGHT_AUTO, cache, UiModeManager.MODE_NIGHT_YES, applied::add)

        assertEquals(listOf(UiModeManager.MODE_NIGHT_AUTO), applied)
        assertEquals("0", cache.readText())
    }

    @Test internal fun failedCacheWriteDoesNotPreventTheNextAttempt() {
        val cache = File(folder.root, "missing/launch_night_mode")
        val applied = mutableListOf<Int>()

        repeat(2) { updateLaunchNightMode(UiModeManager.MODE_NIGHT_NO, cache, null, applied::add) }

        assertEquals(listOf(UiModeManager.MODE_NIGHT_NO, UiModeManager.MODE_NIGHT_NO), applied)
        assertFalse(cache.exists())
    }

    @Test internal fun failedNativeApplyDoesNotCacheSuccess() {
        val cache = File(folder.root, "launch_night_mode")
        val applied = mutableListOf<Int>()
        assertThrows(IllegalStateException::class.java) {
            updateLaunchNightMode(UiModeManager.MODE_NIGHT_YES, cache, null) { error("UiModeManager unavailable") }
        }
        assertFalse(cache.exists())

        updateLaunchNightMode(UiModeManager.MODE_NIGHT_YES, cache, null, applied::add)
        assertEquals(listOf(UiModeManager.MODE_NIGHT_YES), applied)
        assertEquals("2", cache.readText())
    }
}
