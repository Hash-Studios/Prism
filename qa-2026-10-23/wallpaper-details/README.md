# Wallpaper detail discovery proof

Before captures use base dc3a4d953. After captures use the final feature tree, with wallpaper_detail_screen.dart SHA256 28cd06cdf6873c359a1015fa99a9711180f6cf37c5fe9a4e84a6201930a96c90.

Both platforms show Wallhaven wallpaper we91xr before and after. The after screenshots were captured from freshly installed debug builds with real catalog data. Feed and nested-detail captures show recommendations opening the same detail UI. The iOS hold menu exposes favourite, share, and reset; the clock preview retains Lock and Home controls. No wallpaper was applied, purchased, shared, reported, or favourited during this QA.

## Local checks

- Final affected suite: 788 passed, 1 skipped, 0 failed.
- Full analyzer: no errors or warnings, 311 info findings; --no-fatal-infos passed.
- Format, localization, diff checks passed. Code generation completed.
- iOS Simulator debug build and Android debug APK build passed.
- Widget regressions prove A -> B -> A visit isolation and Back restoration of scroll, pages, and tint; canonical loading keeps the real destination Hero and decoded thumbnail visible through a 240ms flight; hold interruption and lifecycle cancellation are covered.

## Full-suite limitation

The full repository run did not pass. Profile follow/unfollow mocks, image-error database initialization, and topic unsubscribe failures reproduce at the unchanged base. The run also stalled in notification_permission_value_action_test.dart and was stopped. Feature-related test migrations from that run pass in the final affected suite. Hosted CI is a separate gate.

## Motion evidence

Design Compare MCP 0.12.0 extracted the supplied references and final simulator recordings. Reference opening frames support about 230ms; the route uses 240ms. Reference hold reveal supports about 160ms. Both final compare_motion results are attached as JSON.

Timing remains inconclusive. The final opening recording yielded 19 sparse frames versus 30 reference frames; hold yielded 10 versus 24. Energy scores measure motion energy only, not fidelity. The recordings do not prove exact curves or cadence. Deterministic tests verify route duration, visible expansion, hold reversal continuity, and reduced-motion behavior.

Recordings are unaligned debug simulator captures and should be treated as diagnostic evidence, not polished demonstrations.
