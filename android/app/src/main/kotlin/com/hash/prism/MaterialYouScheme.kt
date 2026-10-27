package com.hash.prism

/** Maps the Android 12 and 13 tonal palettes to Material 3 colour roles, keyed by the Dart ColorScheme field names. */
internal object MaterialYouScheme {
    /** The tone of each published shade, in shade order 0, 10, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000. */
    val shadeTones = intArrayOf(100, 99, 95, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0)

    class Palettes(
        val accent1: IntArray,
        val accent2: IntArray,
        val accent3: IntArray,
        val neutral1: IntArray,
        val neutral2: IntArray,
    )

    fun tone(palette: IntArray, tone: Int): Int {
        val target = tone.coerceIn(0, 100)
        val exact = shadeTones.indexOf(target)
        if (exact >= 0) return palette[exact]
        val hi = shadeTones.indexOfLast { it > target }
        val lo = hi + 1
        val t = (shadeTones[hi] - target).toDouble() / (shadeTones[hi] - shadeTones[lo])
        return mix(palette[hi], palette[lo], t)
    }

    fun fromPalettes(palettes: Palettes, dark: Boolean): Map<String, Int> {
        val colors = linkedMapOf<String, Int>()
        fun put(role: String, palette: IntArray, level: Int) {
            colors[role] = tone(palette, level)
        }
        val a1 = palettes.accent1
        val a2 = palettes.accent2
        val a3 = palettes.accent3
        val n1 = palettes.neutral1
        val n2 = palettes.neutral2

        put("primary", a1, if (dark) 80 else 40)
        put("onPrimary", a1, if (dark) 20 else 100)
        put("primaryContainer", a1, if (dark) 30 else 90)
        put("onPrimaryContainer", a1, if (dark) 90 else 10)
        put("secondary", a2, if (dark) 80 else 40)
        put("onSecondary", a2, if (dark) 20 else 100)
        put("secondaryContainer", a2, if (dark) 30 else 90)
        put("onSecondaryContainer", a2, if (dark) 90 else 10)
        put("tertiary", a3, if (dark) 80 else 40)
        put("onTertiary", a3, if (dark) 20 else 100)
        put("tertiaryContainer", a3, if (dark) 30 else 90)
        put("onTertiaryContainer", a3, if (dark) 90 else 10)

        put("primaryFixed", a1, 90)
        put("primaryFixedDim", a1, 80)
        put("onPrimaryFixed", a1, 10)
        put("onPrimaryFixedVariant", a1, 30)
        put("secondaryFixed", a2, 90)
        put("secondaryFixedDim", a2, 80)
        put("onSecondaryFixed", a2, 10)
        put("onSecondaryFixedVariant", a2, 30)
        put("tertiaryFixed", a3, 90)
        put("tertiaryFixedDim", a3, 80)
        put("onTertiaryFixed", a3, 10)
        put("onTertiaryFixedVariant", a3, 30)

        if (dark) {
            colors["error"] = 0xFFFFB4AB.toInt()
            colors["onError"] = 0xFF690005.toInt()
            colors["errorContainer"] = 0xFF93000A.toInt()
            colors["onErrorContainer"] = 0xFFFFDAD6.toInt()
        } else {
            colors["error"] = 0xFFBA1A1A.toInt()
            colors["onError"] = 0xFFFFFFFF.toInt()
            colors["errorContainer"] = 0xFFFFDAD6.toInt()
            colors["onErrorContainer"] = 0xFF410002.toInt()
        }

        put("surface", n1, if (dark) 6 else 98)
        put("onSurface", n1, if (dark) 90 else 10)
        put("surfaceDim", n1, if (dark) 6 else 87)
        put("surfaceBright", n1, if (dark) 24 else 98)
        put("surfaceContainerLowest", n1, if (dark) 4 else 100)
        put("surfaceContainerLow", n1, if (dark) 10 else 96)
        put("surfaceContainer", n1, if (dark) 12 else 94)
        put("surfaceContainerHigh", n1, if (dark) 17 else 92)
        put("surfaceContainerHighest", n1, if (dark) 22 else 90)
        put("onSurfaceVariant", n2, if (dark) 80 else 30)
        put("outline", n2, if (dark) 60 else 50)
        put("outlineVariant", n2, if (dark) 30 else 80)
        colors["shadow"] = 0xFF000000.toInt()
        colors["scrim"] = 0xFF000000.toInt()
        put("inverseSurface", n1, if (dark) 90 else 20)
        put("onInverseSurface", n1, if (dark) 20 else 95)
        put("inversePrimary", a1, if (dark) 40 else 80)
        colors["surfaceTint"] = colors.getValue("primary")
        return colors
    }

    private fun mix(from: Int, to: Int, t: Double): Int {
        var out = 0
        for (shift in intArrayOf(24, 16, 8, 0)) {
            val a = (from shr shift) and 0xFF
            val b = (to shr shift) and 0xFF
            out = out or (Math.round(a + (b - a) * t).toInt() shl shift)
        }
        return out
    }
}
