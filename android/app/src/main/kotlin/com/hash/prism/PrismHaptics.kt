package com.hash.prism

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.annotation.RequiresApi

/**
 * Plays the haptic types that lib/core/haptics/prism_haptics.dart sends.
 *
 * Flutter maps its haptics to weak View constants (VIRTUAL_KEY, CLOCK_TICK) that many phones
 * play softly or not at all. This uses the crispest effect each device supports:
 * composition primitives (API 31+), then predefined effects (API 29-30), then short one-shots.
 */
internal enum class PrismHapticType(val wire: String) {
    SELECTION("selection"), TAP("tap"), IMPACT("impact"), SUCCESS("success"), WARNING("warning"), ERROR("error");

    companion object {
        fun fromWire(value: Any?): PrismHapticType? = entries.firstOrNull { it.wire == value }
    }
}

class PrismHaptics(context: Context) {

    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    // API 30 reports composition support, not support for each primitive, so start at API 31.
    private val hasPrimitives: Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
        vibrator?.areAllPrimitivesSupported(
            VibrationEffect.Composition.PRIMITIVE_CLICK,
            VibrationEffect.Composition.PRIMITIVE_TICK,
        ) == true

    internal fun play(type: PrismHapticType) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            v.vibrate(legacyPattern(type), -1)
            return
        }
        val effect = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && hasPrimitives -> composed(type)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> predefined(type)
            else -> oneShot(type, v.hasAmplitudeControl())
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // USAGE_TOUCH follows the user's system touch feedback setting and intensity.
            v.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(
                effect,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun composed(type: PrismHapticType): VibrationEffect {
        val click = VibrationEffect.Composition.PRIMITIVE_CLICK
        val tick = VibrationEffect.Composition.PRIMITIVE_TICK
        val c = VibrationEffect.startComposition()
        when (type) {
            PrismHapticType.SELECTION -> c.addPrimitive(tick, 0.6f)
            PrismHapticType.TAP -> c.addPrimitive(click, 0.5f)
            PrismHapticType.IMPACT -> c.addPrimitive(click, 1f)
            PrismHapticType.SUCCESS -> c.addPrimitive(click, 0.5f).addPrimitive(click, 1f, 70)
            PrismHapticType.WARNING -> c.addPrimitive(click, 1f).addPrimitive(click, 0.5f, 110)
            else -> c.addPrimitive(click, 1f).addPrimitive(click, 1f, 60).addPrimitive(click, 1f, 60)
        }
        return c.compose()
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun predefined(type: PrismHapticType): VibrationEffect = VibrationEffect.createPredefined(
        when (type) {
            PrismHapticType.SELECTION -> VibrationEffect.EFFECT_TICK
            PrismHapticType.TAP -> VibrationEffect.EFFECT_CLICK
            PrismHapticType.IMPACT, PrismHapticType.ERROR -> VibrationEffect.EFFECT_HEAVY_CLICK
            else -> VibrationEffect.EFFECT_DOUBLE_CLICK
        },
    )

    @RequiresApi(Build.VERSION_CODES.O)
    private fun oneShot(type: PrismHapticType, amplitude: Boolean): VibrationEffect {
        fun shot(ms: Long, amp: Int) =
            VibrationEffect.createOneShot(ms, if (amplitude) amp else VibrationEffect.DEFAULT_AMPLITUDE)
        return when (type) {
            PrismHapticType.SELECTION -> shot(8, 70)
            PrismHapticType.TAP -> shot(12, 120)
            PrismHapticType.IMPACT -> shot(20, 255)
            else -> VibrationEffect.createWaveform(legacyPattern(type), -1)
        }
    }

    // ponytail: fixed millisecond patterns for API 24-25 and waveform fallbacks; no amplitude control there.
    private fun legacyPattern(type: PrismHapticType): LongArray = when (type) {
        PrismHapticType.SELECTION -> longArrayOf(0, 8)
        PrismHapticType.TAP -> longArrayOf(0, 12)
        PrismHapticType.IMPACT -> longArrayOf(0, 20)
        PrismHapticType.SUCCESS -> longArrayOf(0, 12, 70, 20)
        PrismHapticType.WARNING -> longArrayOf(0, 20, 110, 12)
        else -> longArrayOf(0, 20, 60, 20, 60, 20)
    }
}
