package com.hash.prism

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.URLDecoder

class SharedInboxLinksTest {
    private val id = "123e4567-e89b-12d3-a456-426614174000"

    @Test
    fun validIdsAreLowercaseUuidShapes() {
        assertTrue(SharedInboxLinks.isValidId(id))
        assertFalse(SharedInboxLinks.isValidId(id.uppercase()))
        assertFalse(SharedInboxLinks.isValidId("../x"))
        assertFalse(SharedInboxLinks.isValidId(""))
        assertFalse(SharedInboxLinks.isValidId("123e4567-e89b-12d3-a456-4266141740001"))
    }

    @Test
    fun extensionFollowsMimeType() {
        assertEquals("png", SharedInboxLinks.extensionFor("image/png"))
        assertEquals("png", SharedInboxLinks.extensionFor("image/PNG"))
        assertEquals("webp", SharedInboxLinks.extensionFor("image/webp"))
        assertEquals("heic", SharedInboxLinks.extensionFor("image/heic"))
        assertEquals("gif", SharedInboxLinks.extensionFor("image/gif"))
        assertEquals("jpg", SharedInboxLinks.extensionFor("image/jpeg"))
        assertEquals("jpg", SharedInboxLinks.extensionFor(null))
        assertEquals("jpg", SharedInboxLinks.extensionFor("image/bmp"))
    }

    @Test
    fun imageLinkCarriesSafeSourceOnly() {
        assertEquals(
            "prism://share-in?id=$id&src=com.android.chrome",
            SharedInboxLinks.imageLink(id, "com.android.chrome"),
        )
        assertFalse(SharedInboxLinks.imageLink(id, "bad pkg/x").contains("src"))
        assertFalse(SharedInboxLinks.imageLink(id, null).contains("src"))
    }

    @Test
    fun textLinkTrimsEncodesAndRejectsBlank() {
        assertEquals(
            "prism://share-in?text=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1%26c%3Dd%2Be",
            SharedInboxLinks.textLink("  https://example.com/a?b=1&c=d+e  ", null),
        )
        assertEquals("prism://share-in?text=a%20b", SharedInboxLinks.textLink("a b", null))
        assertNull(SharedInboxLinks.textLink("   ", null))
    }

    @Test
    fun textLinkLimitsDecodedLengthTo2048() {
        val link = SharedInboxLinks.textLink("x".repeat(5000), null)!!
        val value = link.substringAfter("text=")
        assertEquals(2048, URLDecoder.decode(value, "UTF-8").length)
    }

    @Test
    fun textLinkDoesNotSplitSurrogatePair() {
        val link = SharedInboxLinks.textLink("x".repeat(2047) + "😀" + "tail", null)!!
        val value = link.substringAfter("text=")
        assertEquals(2047, URLDecoder.decode(value, "UTF-8").length)
    }

    @Test
    fun copyLimitedCopiesExactLimit() {
        val input = ByteArrayInputStream(ByteArray(10) { it.toByte() })
        val output = ByteArrayOutputStream()
        SharedInboxLinks.copyLimited(input, output, 10)
        assertArrayEquals(ByteArray(10) { it.toByte() }, output.toByteArray())
    }

    @Test
    fun copyLimitedRejectsStreamOverLimit() {
        val error = assertThrows(SharedInboxException::class.java) {
            SharedInboxLinks.copyLimited(ByteArrayInputStream(ByteArray(11)), ByteArrayOutputStream(), 10)
        }
        assertEquals("too-large", error.code)
    }

    @Test
    fun copyLimitedRejectsEmptyStream() {
        val error = assertThrows(SharedInboxException::class.java) {
            SharedInboxLinks.copyLimited(ByteArrayInputStream(ByteArray(0)), ByteArrayOutputStream())
        }
        assertEquals("unreadable", error.code)
    }
}
