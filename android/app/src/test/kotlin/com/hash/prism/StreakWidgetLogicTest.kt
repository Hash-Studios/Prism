package com.hash.prism

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

internal class StreakWidgetLogicTest {
    private data class RuleCase(val lastKeptDay: String, val today: String, val freezes: Int, val alive: Boolean, val keptToday: Boolean)

    /** The same cases test/core/coins/streak_rule_fixture_test.dart runs against isStreakAlive in Dart. */
    private val cases: List<RuleCase> by lazy {
        val fixture = generateSequence(File("").absoluteFile) { it.parentFile }
            .map { File(it, "test/fixtures/streak_rule_cases.csv") }
            .first { it.isFile }
        fixture.readLines().drop(1).filter { it.isNotBlank() }.map { line ->
            val cells = line.split(',')
            RuleCase(cells[0], cells[1], cells[2].toInt(), cells[3].toBooleanStrict(), cells[4].toBooleanStrict())
        }
    }

    private fun millis(iso: String): Long = Instant.parse(iso).toEpochMilli()

    @Test internal fun aliveMatchesTheSharedFixtures() {
        assertEquals(20, cases.size)
        cases.forEach { case ->
            assertEquals("alive: $case", case.alive, isStreakAlive(case.lastKeptDay, case.today, case.freezes))
        }
    }

    @Test internal fun displayMatchesTheSharedFixturesAtMiddayUtc() {
        cases.forEach { case ->
            val noon = LocalDate.parse(case.today).atTime(12, 0).toInstant(ZoneOffset.UTC).toEpochMilli()
            val expected = if (case.alive) StreakDisplay(5, case.keptToday) else StreakDisplay(0, false)
            assertEquals("display: $case", expected, streakDisplay(StreakSnapshot(5, case.lastKeptDay, 0, case.freezes), noon))
        }
    }

    @Test internal fun signedOutHasNoDisplay() {
        assertNull(streakDisplay(null, millis("2026-11-11T12:00:00Z")))
    }

    @Test internal fun aZeroCountShowsNoStreakEvenWhenTheDayIsToday() {
        assertEquals(StreakDisplay(0, false), streakDisplay(StreakSnapshot(0, "2026-11-11", 0, 0), millis("2026-11-11T12:00:00Z")))
    }

    @Test internal fun dayKeyUsesTheSnapshotOffsetNotUtc() {
        assertEquals("2026-11-10", streakDayKey(millis("2026-11-10T18:29:59Z"), 330))
        assertEquals("2026-11-11", streakDayKey(millis("2026-11-10T18:30:00Z"), 330))
        assertEquals("2026-11-10", streakDayKey(millis("2026-11-11T07:59:59Z"), -480))
        assertEquals("2026-11-11", streakDayKey(millis("2026-11-11T08:00:00Z"), -480))
        assertEquals("2026-11-12", streakDayKey(millis("2026-11-11T10:00:00Z"), 840))
        assertEquals("1969-12-31", streakDayKey(-1L, 0))
    }

    @Test internal fun nextMidnightIsTheLocalMidnightInEachTimeZone() {
        assertEquals(millis("2026-11-10T18:30:00Z"), nextStreakMidnight(millis("2026-11-10T18:29:59Z"), 330))
        assertEquals(millis("2026-11-11T18:30:00Z"), nextStreakMidnight(millis("2026-11-10T18:30:00Z"), 330))
        assertEquals(millis("2026-11-11T08:00:00Z"), nextStreakMidnight(millis("2026-11-11T07:59:59Z"), -480))
        assertEquals(millis("2026-11-12T00:00:00Z"), nextStreakMidnight(millis("2026-11-11T00:00:00Z"), 0))
        assertEquals(millis("2026-11-11T10:00:00Z"), nextStreakMidnight(millis("2026-11-11T09:00:00Z"), 840))
    }

    @Test internal fun theRingEmptiesAtLocalMidnightAndTheStreakLapsesADayLater() {
        val snapshot = StreakSnapshot(12, "2026-11-10", 330, 0)
        assertEquals(StreakDisplay(12, true), streakDisplay(snapshot, millis("2026-11-10T18:29:59Z")))
        assertEquals(StreakDisplay(12, false), streakDisplay(snapshot, millis("2026-11-10T18:30:00Z")))
        assertEquals(StreakDisplay(12, false), streakDisplay(snapshot, millis("2026-11-11T18:29:59Z")))
        assertEquals(StreakDisplay(0, false), streakDisplay(snapshot, millis("2026-11-11T18:30:00Z")))
    }

    @Test internal fun aFreezeKeepsTheStreakOneMoreDay() {
        val snapshot = StreakSnapshot(12, "2026-11-10", -480, 1)
        assertEquals(StreakDisplay(12, false), streakDisplay(snapshot, millis("2026-11-13T07:59:59Z")))
        assertEquals(StreakDisplay(0, false), streakDisplay(snapshot, millis("2026-11-13T08:00:00Z")))
    }

    @Test internal fun compactUpToTwoByOneAndLargeFromTwoByTwo() {
        assertEquals(StreakWidgetSize.COMPACT, streakWidgetSize(57, 57))
        assertEquals(StreakWidgetSize.COMPACT, streakWidgetSize(130, 57))
        assertEquals(StreakWidgetSize.LARGE, streakWidgetSize(130, 130))
        assertEquals(StreakWidgetSize.COMPACT, streakWidgetSize(0, 0))
    }

    @Test internal fun theTapOpensRewardsWithTheAndroidKind() {
        assertEquals("prism://streak?widget=streak_android", STREAK_WIDGET_LINK)
    }
}
