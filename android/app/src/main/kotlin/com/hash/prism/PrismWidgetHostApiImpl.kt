package com.hash.prism

import android.content.Context
import com.hash.prism.pigeon.PrismWidgetHostApi
import com.hash.prism.pigeon.StreakWidgetSnapshot

internal class PrismWidgetHostApiImpl(context: Context) : PrismWidgetHostApi {
    private val context = context.applicationContext

    override fun setStreakSnapshot(snapshot: StreakWidgetSnapshot?) {
        StreakWidgetProvider.save(
            context,
            snapshot?.let { StreakSnapshot(it.count.toInt(), it.lastKeptDay, it.utcOffsetMinutes.toInt(), it.freezes.toInt()) },
        )
    }

    override fun reloadWallOfTheDay() {
        WotdWidgetProvider.refresh(context)
    }
}
