package com.hash.prism

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException

internal class WotdWidgetLogicTest {
    @Test internal fun malformedStoredUrlDoesNotDiscardFetchedWallCandidate() {
        val fetchedWall = WotdWall("today", "https://cdn.example/today.jpg")

        val candidates = widgetCandidateWalls(
            fetch = { fetchedWall },
            storedUrl = { throw ClassCastException("preference type changed") },
        )

        assertEquals(listOf(fetchedWall), candidates)
    }

    @Test internal fun protectedWallUsesItsPublicPreview() {
        val wall = wotdWallFromUrls("today", "", "https://cdn.example/preview.jpg")
        assertNotNull(wall)
        assertEquals("https://cdn.example/preview.jpg", wall?.url)
        assertEquals("", wall?.originalUrl)
        assertEquals("prism://share?id=today&source=prism&url=&thumb=https%3A%2F%2Fcdn.example%2Fpreview.jpg", wotdShareLink(wall!!))
    }

    @Test internal fun previewDoesNotReplaceTheOriginalForSettingWallpaper() {
        val wall = wotdWallFromUrls("today", "https://cdn.example/full.jpg", "https://cdn.example/thumb.jpg")!!
        assertEquals("https://cdn.example/thumb.jpg", wall.url)
        assertEquals("https://cdn.example/full.jpg", wall.originalUrl)
        assertEquals("https://cdn.example/full.jpg", wotdWallFromUrls("old", wall.originalUrl, null)?.url)
        assertNull(wotdWallFromUrls("missing", " ", null))
    }

    @Test internal fun documentUrlEncodesEveryPart() {
        assertEquals(
            "https://firestore.googleapis.com/v1/projects/prism-wallpapers/databases/(default)/documents/walls/abc?key=AIza-key_1",
            firestoreDocumentUrl("prism-wallpapers", "walls", "abc", "AIza-key_1"),
        )
        val hostile = firestoreDocumentUrl("p", "walls", "../x y?z", "k&1")
        assertTrue(hostile, hostile.endsWith("/documents/walls/..%2Fx%20y%3Fz?key=k%261"))
    }

    @Test internal fun shareLinkOpensTheWallInPrism() {
        assertEquals(
            "prism://share?id=wall-1&source=prism&url=https%3A%2F%2Fcdn.example%2Fa%20b.jpg%3Fx%3D1%26y%3D2",
            wotdShareLink(WotdWall("wall-1", "https://cdn.example/a b.jpg?x=1&y=2")),
        )
        assertNull(wotdShareLink(WotdWall("", "https://cdn.example/a.jpg")))
    }

    @Test internal fun wallKeyChangesWhenThePreviewChanges() {
        assertNotEquals(WotdWall("wall-1", "https://a/old.jpg").key, WotdWall("wall-1", "https://a/b.jpg").key)
        assertNotEquals(WotdWall("wall-1", "https://a/b.jpg").key, WotdWall("wall-1", "https://a/b.jpg", "").key)
    }

    @Test internal fun wallpaperSampleSizeKeepsAtLeastTheScreenSize() {
        assertEquals(1, wallpaperSampleSize(1080, 2400, 1080, 2400))
        assertEquals(2, wallpaperSampleSize(4000, 6000, 1080, 2400))
        assertEquals(4, wallpaperSampleSize(8000, 12000, 1080, 2400))
        assertEquals(1, wallpaperSampleSize(800, 600, 1080, 2400))
    }

    @Test internal fun wallpaperSampleSizeCapsThePixelCount() {
        assertEquals(2, wallpaperSampleSize(6000, 4000, 1080, 2400, 12_000_000L))
        assertEquals(1, wallpaperSampleSize(3000, 4000, 0, 0))
        assertEquals(1, wallpaperSampleSize(0, 0, 1080, 2400))
    }

    @Test internal fun timeoutNeverPassesTheDeadline() {
        assertEquals(4000, timeoutWithin(4000, 10_000L, 1_000L))
        assertEquals(500, timeoutWithin(4000, 1_500L, 1_000L))
        assertThrows(IOException::class.java) { timeoutWithin(4000, 1_000L, 1_000L) }
        assertThrows(IOException::class.java) { timeoutWithin(4000, 900L, 1_000L) }
    }

    @Test internal fun copyStopsAtTheDeadlineTheSizeCapAndEmptyBodies() {
        val output = ByteArrayOutputStream()
        assertEquals(3L, copyWithin(ByteArrayInputStream(byteArrayOf(1, 2, 3)), output, 10, 100L) { 50L })
        assertArrayEquals(byteArrayOf(1, 2, 3), output.toByteArray())
        assertThrows(IOException::class.java) { copyWithin(ByteArrayInputStream(byteArrayOf(1)), ByteArrayOutputStream(), 10, 100L) { 101L } }
        assertThrows(IOException::class.java) { copyWithin(ByteArrayInputStream(byteArrayOf(1, 2)), ByteArrayOutputStream(), 1, 100L) { 0L } }
        assertThrows(IOException::class.java) { copyWithin(ByteArrayInputStream(byteArrayOf()), ByteArrayOutputStream(), 10, 100L) { 0L } }
    }

    @Test internal fun certificateFingerprintIsUppercaseHexWithoutColons() {
        assertEquals("A9993E364706816ABA3E25717850C26C9CD0D89D", certificateFingerprint("abc".toByteArray()))
        assertEquals("DA39A3EE5E6B4B0D3255BFEF95601890AFD80709", certificateFingerprint(byteArrayOf()))
        assertEquals(40, certificateFingerprint(byteArrayOf(0, -1, 127)).length)
    }
}
