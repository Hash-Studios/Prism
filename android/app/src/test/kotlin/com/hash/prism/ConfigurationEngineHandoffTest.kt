package com.hash.prism

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Test

internal class ConfigurationEngineHandoffTest {
    private class Engine(val name: String, val shellArgs: List<String> = emptyList()) {
        var destructions = 0
    }

    @Test fun repeatedAcquireReturnsTheActivityEngineAndDestroysItOnce() {
        val expiry = mutableListOf<() -> Unit>()
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, { expiry.add(it) })
        val owner = handoff.owner("activity")
        val first = owner.acquire { Engine("first") }

        assertSame(first, owner.acquire { Engine("unexpected") })
        owner.release(changingConfigurations = false, finishing = true)
        owner.release(changingConfigurations = false, finishing = true)
        assertEquals(1, first.destructions)
        assertEquals(0, expiry.size)
    }

    @Test fun freshEngineReceivesLaunchShellArguments() {
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val owner = handoff.owner("activity")

        val engine = owner.acquire(arrayOf("--trace-startup", "--enable-software-rendering")) {
            Engine("fresh", it.toList())
        }

        assertEquals(listOf("--trace-startup", "--enable-software-rendering"), engine.shellArgs)
        assertSame(engine, owner.acquire(arrayOf("--different")) { Engine("unexpected", it.toList()) })
        owner.release(changingConfigurations = false, finishing = true)
        assertEquals(1, engine.destructions)
    }

    @Test fun liveActivitiesOwnDifferentEngines() {
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val firstOwner = handoff.owner("first")
        val secondOwner = handoff.owner("second")
        val first = firstOwner.acquire { Engine("first") }
        val second = secondOwner.acquire { Engine("second") }

        assertNotSame(first, second)
        assertEquals(listOf("first", "second"), listOf(first.name, second.name))
        firstOwner.release(changingConfigurations = false, finishing = true)
        assertEquals(listOf(1, 0), listOf(first.destructions, second.destructions))
        secondOwner.release(changingConfigurations = false, finishing = true)
        assertEquals(listOf(1, 1), listOf(first.destructions, second.destructions))
    }

    @Test fun onlyMatchingReplacementClaimsTheEngineBeforeFragmentAcquisition() {
        val expiry = mutableListOf<() -> Unit>()
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, { expiry.add(it) })
        val original = handoff.owner("original")
        val engine = original.acquire { Engine("running", it.toList()) }
        original.release(changingConfigurations = true, finishing = false)

        val unrelated = handoff.owner("unrelated")
        val otherEngine = unrelated.acquire { Engine("unrelated") }
        val replacement = handoff.owner("original")
        expiry.single().invoke()
        val reclaimed = replacement.acquire(arrayOf("--trace-startup")) { Engine("unexpected", it.toList()) }

        assertSame(engine, reclaimed)
        assertEquals("unrelated", otherEngine.name)
        assertEquals(0, engine.destructions)
        assertEquals(emptyList<String>(), reclaimed.shellArgs)
        replacement.release(changingConfigurations = false, finishing = true)
        unrelated.release(changingConfigurations = false, finishing = true)
        assertEquals(listOf(1, 1), listOf(engine.destructions, otherEngine.destructions))
    }

    @Test fun unclaimedEngineExpiresAndIsDestroyedExactlyOnce() {
        val expiry = mutableListOf<() -> Unit>()
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, { expiry.add(it) })
        val original = handoff.owner("original")
        val engine = original.acquire { Engine("abandoned") }
        original.release(changingConfigurations = true, finishing = false)

        expiry.single().invoke()
        expiry.single().invoke()
        val later = handoff.owner("original")
        val fresh = later.acquire { Engine("fresh") }

        assertEquals(1, engine.destructions)
        assertEquals("fresh", fresh.name)
        assertNotSame(engine, fresh)
        later.release(changingConfigurations = false, finishing = true)
        assertEquals(1, fresh.destructions)
    }

    @Test fun staleExpiryDoesNotDestroyClaimedEngineOrAnotherPendingEngine() {
        val expiry = mutableListOf<() -> Unit>()
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, { expiry.add(it) })
        val original = handoff.owner("original")
        val engine = original.acquire { Engine("running") }
        original.release(changingConfigurations = true, finishing = false)
        val replacement = handoff.owner("original")
        assertSame(engine, replacement.acquire { Engine("unexpected") })
        val other = handoff.owner("other")
        val otherEngine = other.acquire { Engine("other") }
        other.release(changingConfigurations = true, finishing = false)

        expiry.first().invoke()
        val otherReplacement = handoff.owner("other")
        assertSame(otherEngine, otherReplacement.acquire { Engine("unexpected") })
        expiry.last().invoke()
        assertEquals(listOf(0, 0), listOf(engine.destructions, otherEngine.destructions))
        replacement.release(changingConfigurations = false, finishing = true)
        otherReplacement.release(changingConfigurations = false, finishing = true)
        assertEquals(listOf(1, 1), listOf(engine.destructions, otherEngine.destructions))
    }

    @Test fun replacingAnUnclaimedHandoffDestroysItWithoutExpiringTheNewOne() {
        val expiry = mutableListOf<() -> Unit>()
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, { expiry.add(it) })
        val original = handoff.owner("original")
        val engine = original.acquire { Engine("abandoned") }
        original.release(changingConfigurations = true, finishing = false)
        val other = handoff.owner("other")
        val otherEngine = other.acquire { Engine("other") }
        other.release(changingConfigurations = true, finishing = false)

        assertEquals(1, engine.destructions)
        expiry.first().invoke()
        assertEquals(0, otherEngine.destructions)
        expiry.last().invoke()
        expiry.last().invoke()
        assertEquals(listOf(1, 1), listOf(engine.destructions, otherEngine.destructions))
    }

    @Test fun processDeathCreatesFreshEngineEvenWithTheSameRestoredKey() {
        val oldProcess = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val original = oldProcess.owner("saved-key")
        val oldEngine = original.acquire { Engine("old-process") }
        original.release(changingConfigurations = true, finishing = false)
        val newProcess = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val restored = newProcess.owner("saved-key")

        val fresh = restored.acquire { Engine("new-process") }

        assertEquals("new-process", fresh.name)
        assertNotSame(oldEngine, fresh)
        restored.release(changingConfigurations = false, finishing = true)
        assertEquals(1, fresh.destructions)
    }

    @Test fun finishingWinsOverConfigurationChangeAndOrdinaryDestroyAlsoEndsTheEngine() {
        val expiry = mutableListOf<() -> Unit>()
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, { expiry.add(it) })
        val finishing = handoff.owner("finishing")
        val finishingEngine = finishing.acquire { Engine("finishing") }
        val ordinary = handoff.owner("ordinary")
        val ordinaryEngine = ordinary.acquire { Engine("ordinary") }

        finishing.release(changingConfigurations = true, finishing = true)
        ordinary.release(changingConfigurations = false, finishing = false)

        assertEquals(listOf(1, 1), listOf(finishingEngine.destructions, ordinaryEngine.destructions))
        assertEquals(0, expiry.size)
    }

    @Test fun retainedEngineRestoresEnabledFrameworkBack() {
        assertRetainedBackState(true)
    }

    @Test fun retainedEngineRestoresDisabledFrameworkBack() {
        assertRetainedBackState(false)
    }

    private fun assertRetainedBackState(frameworkHandlesBack: Boolean) {
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val original = handoff.owner("original")
        val engine = original.acquire { Engine("running") }
        original.release(changingConfigurations = true, finishing = false, frameworkHandlesBack = frameworkHandlesBack)
        val replacement = handoff.owner("original")
        val restored = mutableListOf<Boolean>()

        replacement.restoreFrameworkHandlesBack { restored.add(it) }

        assertEquals(listOf(frameworkHandlesBack), restored)
        assertSame(engine, replacement.acquire { Engine("unexpected") })
        replacement.release(changingConfigurations = false, finishing = true)
        assertEquals(1, engine.destructions)
    }

    @Test fun freshAndProcessDeathOwnersDoNotRestoreAnotherEnginesBackState() {
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val original = handoff.owner("original")
        original.acquire { Engine("running") }
        original.release(changingConfigurations = true, finishing = false, frameworkHandlesBack = true)
        val restored = mutableListOf<Boolean>()
        handoff.owner("original").restoreFrameworkHandlesBack { restored.add(it) }
        assertEquals(listOf(true), restored)

        val unrelated = handoff.owner("unrelated")
        unrelated.restoreFrameworkHandlesBack { restored.add(it) }
        val newProcess = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val fresh = newProcess.owner("original")
        fresh.restoreFrameworkHandlesBack { restored.add(it) }

        assertEquals(listOf(true), restored)
        assertEquals("fresh", fresh.acquire { Engine("fresh") }.name)
    }

    @Test fun nextReplacementUsesTheLatestFrameworkBackState() {
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val original = handoff.owner("original")
        val engine = original.acquire { Engine("running") }
        original.release(changingConfigurations = true, finishing = false, frameworkHandlesBack = true)
        val replacement = handoff.owner("original")
        val restored = mutableListOf<Boolean>()
        replacement.restoreFrameworkHandlesBack { restored.add(it) }
        replacement.release(changingConfigurations = true, finishing = false, frameworkHandlesBack = false)

        val nextReplacement = handoff.owner("original")
        nextReplacement.restoreFrameworkHandlesBack { restored.add(it) }

        assertEquals(listOf(true, false), restored)
        assertSame(engine, nextReplacement.acquire { Engine("unexpected") })
        nextReplacement.release(changingConfigurations = false, finishing = true)
        assertEquals(1, engine.destructions)
    }

    @Test fun replacementDestroyedBeforeFragmentCreationPreservesInheritedBackState() {
        val handoff = ConfigurationEngineHandoff<Engine>({ it.destructions++ }, {})
        val original = handoff.owner("original")
        val engine = original.acquire { Engine("running") }
        original.release(changingConfigurations = true, finishing = false, frameworkHandlesBack = true)
        val replacementWithoutFragment = handoff.owner("original")
        replacementWithoutFragment.release(changingConfigurations = true, finishing = false)

        val nextReplacement = handoff.owner("original")
        val restored = mutableListOf<Boolean>()
        nextReplacement.restoreFrameworkHandlesBack { restored.add(it) }

        assertEquals(listOf(true), restored)
        assertSame(engine, nextReplacement.acquire { Engine("unexpected") })
        nextReplacement.release(changingConfigurations = false, finishing = true)
        assertEquals(1, engine.destructions)
    }
}
