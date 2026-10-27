package com.hash.prism

import org.junit.Assert.assertEquals
import org.junit.Test

internal class MaterialYouSchemeTest {
    private val shades = MaterialYouScheme.shadeTones

    private fun grey(tone: Int, offset: Int) = (0xFF shl 24) or (tone shl 16) or (tone shl 8) or (tone + offset)

    private fun palette(offset: Int) = IntArray(shades.size) { grey(shades[it], offset) }

    private val palettes = MaterialYouScheme.Palettes(
        accent1 = palette(101),
        accent2 = palette(102),
        accent3 = palette(103),
        neutral1 = palette(0),
        neutral2 = palette(100),
    )

    private val roles = setOf(
        "primary", "onPrimary", "primaryContainer", "onPrimaryContainer", "primaryFixed", "primaryFixedDim",
        "onPrimaryFixed", "onPrimaryFixedVariant", "secondary", "onSecondary", "secondaryContainer",
        "onSecondaryContainer", "secondaryFixed", "secondaryFixedDim", "onSecondaryFixed", "onSecondaryFixedVariant",
        "tertiary", "onTertiary", "tertiaryContainer", "onTertiaryContainer", "tertiaryFixed", "tertiaryFixedDim",
        "onTertiaryFixed", "onTertiaryFixedVariant", "error", "onError", "errorContainer", "onErrorContainer",
        "surface", "onSurface", "surfaceDim", "surfaceBright", "surfaceContainerLowest", "surfaceContainerLow",
        "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "onSurfaceVariant", "outline",
        "outlineVariant", "shadow", "scrim", "inverseSurface", "onInverseSurface", "inversePrimary", "surfaceTint",
    )

    @Test internal fun toneReturnsExactShades() {
        assertEquals(grey(40, 101), MaterialYouScheme.tone(palettes.accent1, 40))
        assertEquals(grey(100, 101), MaterialYouScheme.tone(palettes.accent1, 100))
        assertEquals(grey(0, 101), MaterialYouScheme.tone(palettes.accent1, 0))
    }

    @Test internal fun toneInterpolatesBetweenNeighbouringShades() {
        assertEquals(grey(98, 0), MaterialYouScheme.tone(palettes.neutral1, 98))
        assertEquals(grey(6, 0), MaterialYouScheme.tone(palettes.neutral1, 6))
        assertEquals(grey(87, 0), MaterialYouScheme.tone(palettes.neutral1, 87))
    }

    @Test internal fun lightSchemeMapsRoles() {
        val light = MaterialYouScheme.fromPalettes(palettes, dark = false)
        assertEquals(roles, light.keys)
        assertEquals(grey(40, 101), light["primary"])
        assertEquals(grey(100, 101), light["onPrimary"])
        assertEquals(grey(40, 102), light["secondary"])
        assertEquals(grey(90, 103), light["tertiaryContainer"])
        assertEquals(grey(98, 0), light["surface"])
        assertEquals(grey(92, 0), light["surfaceContainerHigh"])
        assertEquals(grey(30, 100), light["onSurfaceVariant"])
        assertEquals(0xFFBA1A1A.toInt(), light["error"])
        assertEquals(light["primary"], light["surfaceTint"])
    }

    @Test internal fun darkSchemeMapsRoles() {
        val dark = MaterialYouScheme.fromPalettes(palettes, dark = true)
        assertEquals(roles, dark.keys)
        assertEquals(grey(80, 101), dark["primary"])
        assertEquals(grey(6, 0), dark["surface"])
        assertEquals(grey(22, 0), dark["surfaceContainerHighest"])
        assertEquals(grey(60, 100), dark["outline"])
        assertEquals(grey(40, 101), dark["inversePrimary"])
        assertEquals(grey(90, 101), dark["primaryFixed"])
    }
}
