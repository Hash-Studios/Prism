package com.hash.prism

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.File
import java.nio.file.Files

class WallpaperCropFileTest {
    @Test
    fun overlappingCopiesRemainReadableWithImageExtensions() {
        val directory = Files.createTempDirectory("wallpaper-crop-test").toFile()
        val firstSource = File(directory, "first.png").apply { writeBytes(byteArrayOf(1, 2, 3)) }
        val secondSource = File(directory, "second.png").apply { writeBytes(byteArrayOf(4, 5, 6)) }
        val cropFolder = File(directory, "wallpaper_crop")

        try {
            val firstCopy = copyWallpaperCropFile(firstSource, cropFolder)
            val secondCopy = copyWallpaperCropFile(secondSource, cropFolder)

            assertNotEquals(firstCopy, secondCopy)
            assertEquals("png", firstCopy.extension)
            assertEquals("png", secondCopy.extension)
            assertArrayEquals(byteArrayOf(1, 2, 3), firstCopy.readBytes())
            assertArrayEquals(byteArrayOf(4, 5, 6), secondCopy.readBytes())

            val extensionlessSource = File(directory, "extensionless").apply { writeBytes(byteArrayOf(7)) }
            val extensionlessCopy = copyWallpaperCropFile(extensionlessSource, cropFolder)
            assertEquals("jpg", extensionlessCopy.extension)

            val existingCopies = cropFolder.listFiles()!!.toSet()
            assertThrows(kotlin.io.NoSuchFileException::class.java) {
                copyWallpaperCropFile(File(directory, "missing.png"), cropFolder)
            }
            assertEquals(existingCopies, cropFolder.listFiles()!!.toSet())
        } finally {
            directory.deleteRecursively()
        }
    }
}
