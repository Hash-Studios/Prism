package com.hash.prism

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.File
import java.io.IOException

internal class MediaOperationTest {
    @Test fun interruptedCopyRetriesAfterConfirmedRollback() {
        val harness = RetryHarness()
        val target = File.createTempFile("prism-publish-test", ".tmp")
        var publishedFiles = 0
        try {
            val code = harness.run { operation, attempt ->
                operation.beforeMutation()
                try {
                    if (attempt == 1) {
                        closed = true
                        Thread.currentThread().interrupt()
                    }
                    target.outputStream().use { PrismImageTransfer.copy(ByteArrayInputStream(byteArrayOf(1)), it) }
                    publishedFiles++
                } catch (error: Exception) {
                    operation.rollback(error) { target.delete() || !target.exists() }
                    throw error
                }
            }

            assertEquals("SUCCESS", code)
            assertEquals(2, harness.attempts)
            assertEquals(1, publishedFiles)
            assertArrayEquals(byteArrayOf(1), target.readBytes())
        } finally {
            Thread.interrupted()
            target.delete()
        }
    }

    @Test fun failedOrZeroPublishRollbackDoesNotRetry() {
        for (removeMutation in listOf<() -> Boolean>({ false }, { throw SecurityException("delete denied") })) {
            val harness = RetryHarness()
            var insertedRows = 0
            val code = harness.run { operation, _ ->
                operation.beforeMutation()
                insertedRows++
                val error = IOException("publish failed")
                closed = true
                operation.rollback(error, removeMutation)
                throw error
            }

            assertEquals("DOWNLOAD_FAILED", code)
            assertEquals(1, harness.attempts)
            assertEquals(1, insertedRows)
        }
    }

    @Test fun postCommitStagedCleanupAndToastFailureDoNotRetry() {
        for (error in listOf(IOException("staged cleanup failed"), IllegalStateException("toast dispatch failed"), IOException("scanner failed"))) {
            val harness = RetryHarness()
            val publishedFiles = mutableListOf<String>()
            var toasts = 0
            val code = harness.run { operation, _ ->
                try {
                    operation.beforeMutation()
                    publishedFiles.add("published.jpg")
                    toasts++
                    closed = true
                } finally {
                    throw error
                }
            }

            assertEquals("DOWNLOAD_FAILED", code)
            assertEquals(1, harness.attempts)
            assertEquals(listOf("published.jpg"), publishedFiles)
            assertEquals(1, toasts)
        }
    }

    @Test fun failureAfterPartialDeletionDoesNotRetryOrReportNotFound() {
        for (fallback in listOf("CLEAR_FAILED", "DELETE_FAILED")) {
            val harness = RetryHarness(fallback = fallback)
            val rows = mutableSetOf("old-download")
            val deleted = mutableListOf<String>()
            val code = harness.run { operation, _ ->
                operation.beforeMutation()
                deleted.addAll(rows)
                rows.clear()
                rows.add("new-download")
                closed = true
                operation.beforeMutation()
                throw IOException("cache cleanup failed")
            }

            assertEquals(fallback, code)
            assertEquals(1, harness.attempts)
            assertEquals(listOf("old-download"), deleted)
            assertEquals(setOf("new-download"), rows)
        }
    }

    @Test fun closeBeforeMutationRetriesWithoutLeavingAnArtifact() {
        for (startClosed in listOf(false, true)) {
            val harness = RetryHarness(closed = startClosed)
            val insertedAttempts = mutableListOf<Int>()
            val code = harness.run { operation, attempt ->
                if (attempt == 1) closed = true
                operation.beforeMutation()
                insertedAttempts.add(attempt)
            }

            assertEquals("SUCCESS", code)
            assertEquals(2, harness.attempts)
            assertEquals(listOf(2), insertedAttempts)
        }
    }

    @Test fun genuineFailureRacingCloseRetriesOnceThenReturnsNormalFailure() {
        val harness = RetryHarness()
        var downloads = 0
        val code = harness.run { _, attempt ->
            downloads++
            if (attempt == 1) closed = true
            throw IOException("provider unavailable")
        }

        assertEquals("DOWNLOAD_FAILED", code)
        assertEquals(2, harness.attempts)
        assertEquals(2, downloads)
    }

    private class RetryHarness(var closed: Boolean = false, private val fallback: String = "DOWNLOAD_FAILED") {
        var attempts = 0
            private set

        fun run(task: RetryHarness.(MediaOperation, Int) -> Unit): String {
            while (true) {
                attempts++
                val operation = MediaOperation { closed }
                try {
                    operation.ensureOpen()
                    task(operation, attempts)
                    return "SUCCESS"
                } catch (error: Throwable) {
                    val code = mediaFailureCode(fallback, operation.failure(error))
                    if (code == "ENGINE_DETACHED" && attempts == 1) {
                        closed = false
                        Thread.interrupted()
                        continue
                    }
                    return code
                }
            }
        }
    }
}
