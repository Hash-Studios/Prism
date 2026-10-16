package com.hash.prism

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

internal class ConfigurationEngineHandoffTest {
    private class Engine {
        var destructions = 0
    }

    private val posted = mutableListOf<() -> Unit>()
    private val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, { posted.add(it) })

    @Test internal fun replacementTakesTheKeptEngineAndBackState() {
        val engine = Engine()
        handoff.release(engine, keep = true, frameworkHandlesBack = true)

        val retained = handoff.take()!!
        posted.forEach { it() }

        assertSame(engine, retained.engine)
        assertTrue(retained.frameworkHandlesBack)
        assertEquals(0, engine.destructions)
        assertNull(handoff.take())
    }

    @Test internal fun engineIsDestroyedWhenNotKept() {
        val engine = Engine()
        handoff.release(engine, keep = false, frameworkHandlesBack = true)

        assertEquals(1, engine.destructions)
        assertNull(handoff.take())
        assertTrue(posted.isEmpty())
    }

    @Test internal fun engineNobodyTookIsDestroyedOnTheNextMessage() {
        val engine = Engine()
        handoff.release(engine, keep = true, frameworkHandlesBack = false)

        posted.forEach { it() }

        assertEquals(1, engine.destructions)
        assertNull(handoff.take())
    }

    @Test internal fun newerKeptEngineReplacesAndDestroysTheOlderOne() {
        val older = Engine()
        val newer = Engine()
        handoff.release(older, keep = true, frameworkHandlesBack = false)
        handoff.release(newer, keep = true, frameworkHandlesBack = false)

        assertEquals(1, older.destructions)
        assertSame(newer, handoff.take()!!.engine)
        posted.forEach { it() }
        assertEquals(listOf(1, 0), listOf(older.destructions, newer.destructions))
    }
}
