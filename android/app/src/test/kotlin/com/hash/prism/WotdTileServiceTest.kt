package com.hash.prism

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

internal class WotdTileServiceTest {
    @Test fun publicUrlWins() {
        assertEquals(
            "https://img.example.com/wall.jpg",
            WotdTileService.tileSource(" https://img.example.com/wall.jpg ", """{"assetKey":"wotd:doc"}"""),
        )
    }

    @Test fun protectedWallUsesTheDownloadedOriginalKey() {
        assertEquals("wotd:doc", WotdTileService.tileSource("", """{"documentId":"doc","assetKey":"wotd:doc"}"""))
    }

    @Test fun protectedWallWithNoDownloadHasNoSource() {
        assertNull(WotdTileService.tileSource("", null))
        assertNull(WotdTileService.tileSource("", "not json"))
        assertNull(WotdTileService.tileSource(null, """{"assetKey":"https://img.example.com/other.jpg"}"""))
    }
}
