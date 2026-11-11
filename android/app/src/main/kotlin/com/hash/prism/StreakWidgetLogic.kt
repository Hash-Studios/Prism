package com.hash.prism

import java.time.LocalDate
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit

internal const val STREAK_WIDGET_LINK = "prism://streak?widget=streak_android"

private const val DAY_MS = 86_400_000L
private const val MINUTE_MS = 60_000L
private val DAY_KEY = Regex("""^\d{4}-\d{2}-\d{2}$""")

/** What the app writes for the streak widget. The same fields as the iOS snapshot. */
internal data class StreakSnapshot(val count: Int, val lastKeptDay: String, val utcOffsetMinutes: Int, val freezes: Int)

internal data class StreakDisplay(val count: Int, val keptToday: Boolean)

internal enum class StreakWidgetSize { COMPACT, LARGE }

/** The day key (yyyy-MM-dd) of [epochMillis] at a fixed UTC offset. */
internal fun streakDayKey(epochMillis: Long, utcOffsetMinutes: Int): String =
    LocalDate.ofEpochDay(Math.floorDiv(epochMillis + utcOffsetMinutes * MINUTE_MS, DAY_MS)).toString()

/** Mirrors dayKeyGap in lib/core/coins/coin_policy.dart. Null when either key is not a real yyyy-MM-dd day. */
internal fun streakDayGap(from: String, to: String): Int? {
    val start = parseDayKey(from) ?: return null
    val end = parseDayKey(to) ?: return null
    return ChronoUnit.DAYS.between(start, end).toInt()
}

/** Mirrors isStreakAlive in lib/core/coins/coin_policy.dart. */
internal fun isStreakAlive(lastKey: String, todayKey: String, freezes: Int): Boolean {
    val gap = streakDayGap(lastKey, todayKey) ?: return false
    return gap <= 1 + freezes
}

/** Null means signed out. A lapsed streak shows 0. */
internal fun streakDisplay(snapshot: StreakSnapshot?, nowMillis: Long): StreakDisplay? {
    snapshot ?: return null
    val today = streakDayKey(nowMillis, snapshot.utcOffsetMinutes)
    if (snapshot.count <= 0 || !isStreakAlive(snapshot.lastKeptDay, today, snapshot.freezes)) return StreakDisplay(0, false)
    return StreakDisplay(snapshot.count, streakDayGap(snapshot.lastKeptDay, today) == 0)
}

/** The first local midnight after [nowMillis] in the streak's time zone. */
internal fun nextStreakMidnight(nowMillis: Long, utcOffsetMinutes: Int): Long {
    val offset = utcOffsetMinutes * MINUTE_MS
    return (Math.floorDiv(nowMillis + offset, DAY_MS) + 1) * DAY_MS - offset
}

/** 1x1 and 2x1 cells are compact. 2x2 and up shows the status line. */
internal fun streakWidgetSize(minWidthDp: Int, maxHeightDp: Int): StreakWidgetSize =
    if (minWidthDp >= 100 && maxHeightDp >= 100) StreakWidgetSize.LARGE else StreakWidgetSize.COMPACT

private fun parseDayKey(key: String): LocalDate? {
    val trimmed = key.trim()
    if (!DAY_KEY.matches(trimmed)) return null
    return try {
        LocalDate.parse(trimmed)
    } catch (_: DateTimeParseException) {
        null
    }
}
