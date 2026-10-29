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

    @Test fun protectedWallWithNoDownloadOpensTodaysWallInPrism() {
        val link = "prism://share?id=doc&source=prism&url=&thumb=https%3A%2F%2Fimg.example.com%2Fp.img"
        assertEquals(link, WotdTileService.openLink(null, " $link "))
    }

    @Test fun aWallpaperTheTileCanSetWinsOverTheLink() {
        assertNull(WotdTileService.openLink("wotd:doc", "prism://share?id=doc&source=prism"))
    }

    @Test fun onlyPrismShareLinksAreOpened() {
        assertNull(WotdTileService.openLink(null, "https://evil.example.com/x"))
        assertNull(WotdTileService.openLink(null, null))
    }
}
