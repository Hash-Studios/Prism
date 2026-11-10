# PRISM-F6 semantics investigation

PRISM-F6 matches a reproducible Flutter 3.47.8 semantics defect. This change adds
route coverage and an SDK qualification probe. It does not fix the production
framework or establish the exact app widget sequence that triggered the events.
Keep F6 unresolved until a corrected SDK ships and production evidence supports closure.

## Evidence

The incident brief reports three events across two users. The latest two occurred
on production Android in Prism 3.25.0+367, Shorebird patch 0, on a rooted OnePlus
A5010 running Android 9. They occurred about eight seconds apart around
SpinWheelRoute dismissal to DashboardRoute at 02:45 IST on 2026-11-09.
The older event was in Prism 3.5.0+342 on 2026-10-19. These event facts come from
the supplied Sentry investigation, not a fresh event or replay retrieval.

The fetched `v3.25.0+367` tag resolves to
`3223ad3855b26fca19738fde03bb86d369b2fd9a` and pins Flutter 3.47.8 in `.fvmrc`.
The incident brief establishes that the release preceded PR #849. F6 has no
feature-hint frames. This investigation makes no attribution to that PR.

[Flutter issue #195316](https://github.com/flutter/flutter/issues/195316)
reports the same null assertion at `geometry!.hidden` in
`_RenderObjectSemantics._buildSemanticsSubtree`. Its reproduction fails locally
on Flutter 3.47.8, framework revision `737ba8f885`.
[Flutter PR #192724](https://github.com/flutter/flutter/pull/192724) was open and
unmerged when checked on 2026-11-09.

## Mechanism

A semantics boundary becomes invisible while a modal barrier blocks its branch.
Changes to a transform and semantics labels invalidate ancestor geometry.
In `PipelineOwner.flushSemantics`, the invisible-node branch reads the parent's
`firstAncestorNodeWithCleanGeometry` cache without refreshing it for the current
`treeShapeToken`. That cache can point to a node whose geometry was cleared.
`ensureSemanticsNode` then reaches `geometry!.hidden` with null geometry.

The SDK probe builds this sequence without any Prism widget. It fails on the
pinned SDK. Adding the upstream call
`parentInSemanticsTree.computeAncestorInfo(treeShapeToken)` immediately before
that cache read makes the same probe pass. This experiment used a temporary copy
of the Flutter package and a temporary package-config override. The shared SDK,
repository SDK pin, and production code were not changed. The original package
configuration was restored after the experiment.

The unmodified probe produced this stack and assertion:

```text
#0      _RenderObjectSemantics._buildSemanticsSubtree (package:flutter/src/rendering/object.dart:6271:61)
#1      _RenderObjectSemantics.ensureSemanticsNode (package:flutter/src/rendering/object.dart:6201:7)
#2      PipelineOwner.flushSemantics (package:flutter/src/rendering/object.dart:1636:18)
Expected: null
  Actual: _TypeError:<Null check operator used on a null value>
```

With the temporary upstream correction, the same reproduction reported:

```text
00:00 +1: All tests passed!
```

This is evidence for a matching framework limitation. The SpinWheel dismissal
breadcrumbs do not identify which render object invalidated geometry in F6.
Changing a route animation or removing accessibility would not be a proven fix.

## Regression checks

Run the app route checks with the unmodified pinned SDK:

```sh
fvm flutter test --no-pub test/features/spin_wheel/spin_wheel_route_semantics_test.dart
```

The fixture uses the production SpinWheelRoute configuration and SpinWheelPage,
with injected coin notifiers and a lightweight DashboardRoute destination.
It covers close-button, system-back, and accessibility-action dismissal, with
normal and reduced motion. Each case opens and closes twice, changes the covered
destination label, and checks every transition frame for framework exceptions.
It verifies that SpinWheel controls remain accessible and destination semantics
return after dismissal. It does not render the full production Dashboard tree.

Run the SDK qualification probe explicitly:

```sh
fvm flutter test --no-pub tool/regressions/prism_f6_semantics_test.dart
```

This probe is adapted from the upstream issue. It deliberately expects correct
semantics behavior and fails on Flutter 3.47.8. It lives outside `test/` so the
known upstream defect does not make the ordinary app suite fail. It does not
catch or accept the null assertion as success. Run it when evaluating a Flutter
or Shorebird engine update that claims to fix this path.

## Device limits and next step

The local Android 16 emulator opened Prism, but its device snapshot helper twice
returned `Android snapshot helper returned insufficient foreground app content`.
Device interaction stopped after the required retry. No successful device
route-dismissal or screenshot proof is claimed. No iOS device run was completed.
Neither platform substitutes for the affected rooted Android 9 OnePlus device.

A production fix requires a qualified Flutter SDK containing the cache refresh,
plus a compatible Shorebird release build. Re-run both tests and device checks
before selecting that SDK. Shipping, deploying, or changing the SDK is outside
this investigation PR. No global error suppression or semantics-flush override
is introduced.
