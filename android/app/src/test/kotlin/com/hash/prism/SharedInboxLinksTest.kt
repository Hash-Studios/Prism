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
import java.io.File
import java.io.InputStream
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class SharedInboxLinksTest {
    private val id = "123e4567-e89b-12d3-a456-426614174000"

    @Test
    fun validIdsAreLowercaseUuidShapes() {
        assertTrue(SharedInboxLinks.isValidId(id))
        assertFalse(SharedInboxLinks.isValidId(id.uppercase()))
        assertFalse(SharedInboxLinks.isValidId("../x"))
        assertFalse(SharedInboxLinks.isValidId(""))
        assertFalse(SharedInboxLinks.isValidId("123e4567-e89b-12d3-a456-4266141740001"))
        assertFalse(SharedInboxLinks.isValidId("-".repeat(36)))
    }

    @Test
    fun ownProviderAuthorityStripsAndroidUserIdPrefix() {
        assertEquals("com.hash.prism.wallpaper_crop", SharedInboxLinks.normalizedAuthority("0@com.hash.prism.wallpaper_crop"))
        assertEquals("com.hash.prism.wallpaper_crop", SharedInboxLinks.normalizedAuthority("-2@com.hash.prism.wallpaper_crop"))
        assertEquals("photos.example", SharedInboxLinks.normalizedAuthority("photos.example"))
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

    @Test
    fun canceledCopyDoesNotWriteMoreBytes() {
        val output = ByteArrayOutputStream()
        Thread.currentThread().interrupt()
        try {
            val error = assertThrows(SharedInboxException::class.java) {
                SharedInboxLinks.copyLimited(ByteArrayInputStream(byteArrayOf(1)), output)
            }
            assertEquals("unreadable", error.code)
            assertEquals(0, output.size())
        } finally {
            Thread.interrupted()
        }
    }

    @Test
    fun timeoutRemovesPartialAndRefusesLateProviderResult() {
        val folder = Files.createTempDirectory("shared-inbox-test").toFile()
        val opened = CountDownLatch(1)
        val release = CountDownLatch(1)
        var closed = false
        val copy = SharedInboxCopy(folder, id, "png") {
            opened.countDown()
            // Simulate a provider that ignores thread interruption while fetching a cloud image.
            while (release.count > 0) {
                try { release.await() } catch (_: InterruptedException) { }
            }
            object : ByteArrayInputStream(byteArrayOf(1)) {
                override fun close() { closed = true; super.close() }
            }
        }
        val worker = Thread(copy.task)
        try {
            worker.start()
            assertTrue(opened.await(2, TimeUnit.SECONDS))
            assertEquals("unreadable", assertThrows(SharedInboxException::class.java) { copy.take(1) }.code)
            release.countDown()
            worker.join(2000)
            assertFalse(worker.isAlive)
            assertTrue(closed)
            assertTrue(folder.listFiles()!!.isEmpty())
        } finally {
            release.countDown()
            worker.join(2000)
            folder.deleteRecursively()
        }
    }

    @Test
    fun timeoutDuringReadRemovesPartBeforeLateReadReturns() {
        val folder = Files.createTempDirectory("shared-inbox-test").toFile()
        val reading = CountDownLatch(1)
        val release = CountDownLatch(1)
        val copy = SharedInboxCopy(folder, id, "png") {
            object : InputStream() {
                override fun read(): Int = error("Uses bulk reads")
                override fun read(buffer: ByteArray): Int {
                    reading.countDown()
                    while (release.count > 0) {
                        try { release.await() } catch (_: InterruptedException) { }
                    }
                    buffer[0] = 1
                    return 1
                }
            }
        }
        val worker = Thread(copy.task)
        try {
            worker.start()
            assertTrue(reading.await(2, TimeUnit.SECONDS))
            assertTrue(File(folder, "$id.part").exists())
            assertThrows(SharedInboxException::class.java) { copy.take(1) }
            assertTrue(folder.listFiles()!!.isEmpty())
            release.countDown()
            worker.join(2000)
            assertFalse(worker.isAlive)
            assertTrue(folder.listFiles()!!.isEmpty())
        } finally {
            release.countDown()
            worker.interrupt()
            worker.join(2000)
            folder.deleteRecursively()
        }
    }

    @Test
    fun timeoutClosesBlockedReadAndAllowsAnotherShare() {
        val folder = Files.createTempDirectory("shared-inbox-test").toFile()
        val reading = CountDownLatch(1)
        val closed = CountDownLatch(1)
        val workerFinished = CountDownLatch(1)
        val copy = SharedInboxCopy(folder, id, "png") {
            object : InputStream() {
                override fun read(): Int = error("Uses bulk reads")
                override fun read(buffer: ByteArray): Int {
                    reading.countDown()
                    while (closed.count > 0) {
                        try { closed.await() } catch (_: InterruptedException) { }
                    }
                    return -1
                }
                override fun close() { closed.countDown() }
            }
        }
        val worker = Thread { try { copy.task.run() } finally { workerFinished.countDown() } }
        try {
            worker.start()
            assertTrue(reading.await(2, TimeUnit.SECONDS))
            assertThrows(SharedInboxException::class.java) { copy.take(1) }
            assertTrue("Timeout must close the provider, not just cancel its Future", closed.await(2, TimeUnit.SECONDS))
            assertTrue(workerFinished.await(2, TimeUnit.SECONDS))
            val retry = SharedInboxCopy(folder, id, "png") { ByteArrayInputStream(byteArrayOf(2)) }
            Thread(retry.task).start()
            assertArrayEquals(byteArrayOf(2), retry.take(2000).readBytes())
        } finally {
            closed.countDown()
            worker.join(2000)
            folder.deleteRecursively()
        }
    }

    @Test
    fun blockedProviderDoesNotQueueTheNextShare() {
        val folder = Files.createTempDirectory("shared-inbox-test").toFile()
        val opening = CountDownLatch(1)
        val release = CountDownLatch(1)
        val finished = CountDownLatch(1)
        val blocked = SharedInboxCopy(folder, id, "png") {
            opening.countDown()
            while (release.count > 0) {
                try { release.await() } catch (_: InterruptedException) { }
            }
            object : ByteArrayInputStream(byteArrayOf(1)) {
                override fun close() { super.close(); finished.countDown() }
            }
        }
        try {
            blocked.start()
            assertTrue(opening.await(2, TimeUnit.SECONDS))
            assertThrows(SharedInboxException::class.java) { blocked.take(1) }
            val next = SharedInboxCopy(folder, "123e4567-e89b-12d3-a456-426614174001", "png") {
                ByteArrayInputStream(byteArrayOf(2))
            }
            next.start()
            assertArrayEquals(byteArrayOf(2), next.take(2000).readBytes())
        } finally {
            release.countDown()
            assertTrue(finished.await(2, TimeUnit.SECONDS))
            folder.deleteRecursively()
        }
    }

    @Test
    fun nativeTakeRejectsAndDeletesInvalidFiles() {
        val folder = Files.createTempDirectory("shared-inbox-test").toFile()
        try {
            val image = File(folder, "$id.png").apply { writeBytes(byteArrayOf(1)) }
            assertEquals(image, SharedInboxLinks.takeFile(folder, id))
            image.writeBytes(byteArrayOf())
            assertEquals("unreadable", assertThrows(SharedInboxException::class.java) { SharedInboxLinks.takeFile(folder, id) }.code)
            assertFalse(image.exists())
            File(folder, "$id.txt").writeBytes(byteArrayOf(1))
            assertEquals("unreadable", assertThrows(SharedInboxException::class.java) { SharedInboxLinks.takeFile(folder, id) }.code)
            assertTrue(folder.listFiles()!!.isEmpty())
            image.mkdir()
            assertEquals("unreadable", assertThrows(SharedInboxException::class.java) { SharedInboxLinks.takeFile(folder, id) }.code)
            assertFalse(image.exists())
            val outside = File(folder.parentFile, "${folder.name}-outside").apply { writeBytes(byteArrayOf(1)) }
            try {
                Files.createSymbolicLink(image.toPath(), outside.toPath())
                assertThrows(SharedInboxException::class.java) { SharedInboxLinks.takeFile(folder, id) }
                assertTrue(outside.exists())
            } finally { outside.delete() }
        } finally { folder.deleteRecursively() }
    }

    @Test
    fun nativeTakeAcceptsAnInboxReachedThroughASymlinkedParent() {
        val root = Files.createTempDirectory("shared-inbox-root").toFile()
        try {
            val data = File(root, "data").apply { mkdirs() }
            val user = File(root, "user").also { Files.createSymbolicLink(it.toPath(), data.toPath()) }
            val folder = File(user, "shared_inbox").apply { mkdirs() }
            val image = File(folder, "$id.png").apply { writeBytes(byteArrayOf(1)) }
            assertEquals(image, SharedInboxLinks.takeFile(folder, id))
            assertTrue(image.exists())
        } finally { root.deleteRecursively() }
    }

    @Test
    fun sweepRemovesAbandonedPartsAndOldFilesButNotActiveCopies() {
        val folder = Files.createTempDirectory("shared-inbox-test").toFile()
        try {
            val partial = File(folder, "$id.part").apply { writeBytes(byteArrayOf(1)) }
            val activeId = "123e4567-e89b-12d3-a456-426614174001"
            val active = File(folder, "$activeId.part").apply { writeBytes(byteArrayOf(1)) }
            val old = File(folder, "old.png").apply { writeBytes(byteArrayOf(1)); setLastModified(1) }
            val recent = File(folder, "recent.png").apply { writeBytes(byteArrayOf(1)) }
            SharedInboxLinks.sweep(folder, setOf(activeId))
            assertFalse(partial.exists())
            assertFalse(old.exists())
            assertTrue(active.exists())
            assertTrue(recent.exists())
        } finally { folder.deleteRecursively() }
    }
}
