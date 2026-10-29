package com.hash.prism

import org.junit.Assert.assertTrue
import org.junit.Test

internal class OfflineTileAssetsTest {
    @Test fun malformedConfigurationDoesNotKeepTileReadyCheckFromFailing() {
        org.junit.Assert.assertEquals(false, tileConfigured { throw ClassCastException("preference type changed") })
        org.junit.Assert.assertEquals(true, tileConfigured { true })
        org.junit.Assert.assertNull(readPreferenceString { throw ClassCastException("preference type changed") })
        org.junit.Assert.assertEquals("valid", readPreferenceString { "valid" })
    }

    @Test fun categoryWallpaperUsesLiveFetchWhenNoRetainedCandidatesExist() {
        var fetched = false

        val wallpaper = MyTileService.categoryWallpaper(emptyList()) {
            fetched = true
            "https://example.com/live.jpg"
        }

        assertTrue(fetched)
        org.junit.Assert.assertEquals("https://example.com/live.jpg", wallpaper)
    }

    @Test fun categoryWallpaperPrefersLiveResultWhenRetainedCandidatesExist() {
        var fetched = false

        val wallpaper = MyTileService.categoryWallpaper(listOf("file-url")) {
            fetched = true
            "https://example.com/live.jpg"
        }

        assertTrue(fetched)
        org.junit.Assert.assertEquals("https://example.com/live.jpg", wallpaper)
    }

    @Test fun categoryWallpaperFallsBackToRetainedCandidateWhenLiveFetchFails() {
        val wallpaper = MyTileService.categoryWallpaper(listOf("file-url")) {
            throw java.io.IOException("offline")
        }

        org.junit.Assert.assertEquals("file-url", wallpaper)
    }

    @Test fun categoryWallpaperPreservesLiveFailureWhenNoRetainedCandidateExists() {
        val failure = java.io.IOException("offline")
        try {
            MyTileService.categoryWallpaper(emptyList()) { throw failure }
            throw AssertionError("Expected live failure")
        } catch (error: java.io.IOException) {
            org.junit.Assert.assertSame(failure, error)
        }
    }
}
