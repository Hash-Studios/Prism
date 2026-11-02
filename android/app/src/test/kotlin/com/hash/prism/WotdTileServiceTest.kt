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
        assertNull(WotdTileService.openLink(null, "prism://share@evil.example.com?id=doc"))
        assertNull(WotdTileService.openLink(null, "prism://share.evil.example.com?id=doc"))
    }

    @Test fun aWallpaperTileWithAnInvalidTargetIsUnavailable() {
        assertEquals(
            false,
            WotdTileService.tileConfiguredForWotd("https://img.example.com/wall.jpg", null) { "invalid" },
        )
    }

    @Test fun aWallpaperTileWithAWrongTypedTargetIsUnavailable() {
        assertEquals(
            false,
            tileConfigured {
                WotdTileService.tileConfiguredForWotd("https://img.example.com/wall.jpg", null) {
                    throw ClassCastException("expected String")
                }
            },
        )
    }

    @Test fun anOpenLinkDoesNotNeedAWallpaperTarget() {
        assertEquals(
            true,
            WotdTileService.tileConfiguredForWotd(null, "prism://share?id=doc") {
                throw ClassCastException("target must not be read for an open link")
            },
        )
    }

    @Test fun aMissingWallpaperTargetDefaultsToBoth() {
        assertEquals(
            true,
            WotdTileService.tileConfiguredForWotd("https://img.example.com/wall.jpg", null) { null },
        )
    }

    @Test fun validWallpaperTargetsKeepTheTileAvailable() {
        for (target in listOf("home", "lock", "both")) {
            assertEquals(
                true,
                WotdTileService.tileConfiguredForWotd("https://img.example.com/wall.jpg", null) { target },
            )
        }
    }

    @Test fun clickResolvesTheActionAfterUnlock() {
        var currentLink: String? = "prism://share?id=old"
        var opened: String? = null
        var applied = false
        val action = deferredTileAction(
            resolveLink = { currentLink },
            openApp = { opened = it },
            applyWallpaper = { applied = true },
        )

        currentLink = null
        action()

        assertNull(opened)
        assertEquals(true, applied)
    }

    @Test fun clickUsesTheLinkThatIsCurrentAfterUnlock() {
        var currentLink: String? = "prism://share?id=old"
        var opened: String? = null
        val action = deferredTileAction(
            resolveLink = { currentLink },
            openApp = { opened = it },
            applyWallpaper = {},
        )

        currentLink = "prism://share?id=current"
        action()

        assertEquals("prism://share?id=current", opened)
    }

}
