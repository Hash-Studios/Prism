package com.hash.prism

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Plays the haptic types that lib/core/haptics/prism_haptics.dart sends.
 *
 * Flutter maps its haptics to weak View constants (VIRTUAL_KEY, CLOCK_TICK) that many phones
 * play softly or not at all. This uses the crispest effect each device supports:
 * composition primitives (API 30+), then predefined effects (API 29), then short one-shots.
 */
class PrismHaptics(context: Context) {

    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    private val hasPrimitives: Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
        vibrator?.areAllPrimitivesSupported(
            VibrationEffect.Composition.PRIMITIVE_CLICK,
            VibrationEffect.Composition.PRIMITIVE_TICK,
        ) == true

    fun play(type: String) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            v.vibrate(legacyPattern(type), -1)
            return
        }
        val effect = when {
            hasPrimitives -> composed(type)
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

    private fun composed(type: String): VibrationEffect {
        val click = VibrationEffect.Composition.PRIMITIVE_CLICK
        val tick = VibrationEffect.Composition.PRIMITIVE_TICK
        val c = VibrationEffect.startComposition()
        when (type) {
            "selection" -> c.addPrimitive(tick, 0.6f)
            "tap" -> c.addPrimitive(click, 0.5f)
            "impact" -> c.addPrimitive(click, 1f)
            "success" -> c.addPrimitive(click, 0.5f).addPrimitive(click, 1f, 70)
            "warning" -> c.addPrimitive(click, 1f).addPrimitive(click, 0.5f, 110)
            else -> c.addPrimitive(click, 1f).addPrimitive(click, 1f, 60).addPrimitive(click, 1f, 60)
        }
        return c.compose()
    }

    private fun predefined(type: String): VibrationEffect = VibrationEffect.createPredefined(
        when (type) {
            "selection" -> VibrationEffect.EFFECT_TICK
            "tap" -> VibrationEffect.EFFECT_CLICK
            "impact", "error" -> VibrationEffect.EFFECT_HEAVY_CLICK
            else -> VibrationEffect.EFFECT_DOUBLE_CLICK
        },
    )

    private fun oneShot(type: String, amplitude: Boolean): VibrationEffect {
        fun shot(ms: Long, amp: Int) =
            VibrationEffect.createOneShot(ms, if (amplitude) amp else VibrationEffect.DEFAULT_AMPLITUDE)
        return when (type) {
            "selection" -> shot(8, 70)
            "tap" -> shot(12, 120)
            "impact" -> shot(20, 255)
            else -> VibrationEffect.createWaveform(legacyPattern(type), -1)
        }
    }

    // ponytail: fixed millisecond patterns for API 24-25 and waveform fallbacks; no amplitude control there.
    private fun legacyPattern(type: String): LongArray = when (type) {
        "selection" -> longArrayOf(0, 8)
        "tap" -> longArrayOf(0, 12)
        "impact" -> longArrayOf(0, 20)
        "success" -> longArrayOf(0, 12, 70, 20)
        "warning" -> longArrayOf(0, 20, 110, 12)
        else -> longArrayOf(0, 20, 60, 20, 60, 20)
    }
}
