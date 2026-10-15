# Codebase slop audit, 15 October 2026

This report records 19 investigated groups against `origin/master` at `c5ef0356`: 18 accepted and fixed groups and one rejected candidate, A5, on `t3/codebase-slop-audit`. The review targeted unnecessary code, weak tests, erased types, misleading comments, and duplicated logic. Caller tracing also exposed several behavior bugs. Those bugs are included because deleting the apparent duplication without understanding its callers would leave incorrect behavior.

Locations marked "baseline" refer to `c5ef0356`; line numbers move after edits. Relative file links open the current implementation. No deployment, schema change, data migration, or store upload is part of this work.

## Scope and method

The app inventory contained 623 non-generated Dart sources across 32 feature directories and shared app code. The test inventory contained 369 Dart files, including 349 `*_test.dart` files and 20 support or fixture files. There were 2,525 textual test registration sites. Loops expand registrations, so this is not a runtime test count.

The review inventoried all app and test paths, searched common candidate patterns, traced callers, and read candidate implementations and their tests. App searches covered catches, unfinished markers, dynamic values, casts, asynchronous wrappers, compatibility paths, resource acquisition, and declaration references. Test searches covered source reads, absence assertions, weak matchers, constructor tests, skips, sleeps, and duplicate fixtures. This was systematic triage with focused semantic review. It was not a manual review of every assertion in all 349 suites, nor an exhaustive security audit.

The server and tooling review covered Functions entrypoints, helpers, migrations, and tests; the Next.js site; Cloudflare worker sources and tests; shell and Dart tools; hooks; workflows; the Makefile; and Firebase configuration. Native review covered Android and iOS channel registration, media operations, download serialization, permissions, widgets, tiles, Pigeon declarations, and manifest reachability. Generated output and the vendored `packages/cloud_functions` implementation were excluded from cleanup.

The requested Workflow tool and `workflow-authoring` skill were unavailable after tool catalog and disk searches. Native Sol delegation provided separate investigation and fix ownership, with one owner per file. The parent agent performed design review and final verification of the combined tree.

The actionable Dart type-safety cases erased known types or converted arbitrary API values with `.toString()`. Valid serialization maps and repository boundaries remain.

## App findings

### A1. Two short-link resolvers disagreed about recursive links

Baseline `lib/core/router/short_link_resolver.dart:58-64` accepted a parsed `ShortCodeIntent`. `lib/main.dart:696,765-772` resolved that intent again. A canonical URL pointing to the same short code, or a cycle, could repeat requests indefinitely. The duplicate resolver at `lib/core/router/deep_link_navigation.dart:78-121` already rejected short-code results.

The fix makes [ShortLinkResolver](../../lib/core/router/short_link_resolver.dart) the shared HTTP and JSON boundary used by [DeepLinkNavigation](../../lib/core/router/deep_link_navigation.dart). It rejects unknown and nested short-code intents, validates canonical strings, preserves URI transformation, and retains network failure classification. Default requests use the HTTP helper rather than retaining an unclosed internally created client. Injected clients remain supported.

Regression scenarios in [resolver tests](../../test/core/router/short_link_resolver_test.dart) and [navigation tests](../../test/core/router/deep_link_navigation_test.dart) cover nested links, malformed canonical values, supported destinations, custom schemes, and error handling. Startup sequencing, referral timing, and analytics remain existing contracts.

### A2. Malformed coin retry entries survived every retry

Baseline `lib/core/coins/coins_service.dart:720-727,828-861` admitted JSON maps without a usable ID. Retry skipped those maps, but removal tracked only nonempty IDs. The persistent queue therefore stayed nonempty and scheduled more work indefinitely.

The locked rewrite in [CoinsService](../../lib/core/coins/coins_service.dart) now removes entries with empty resolved keys as well as completed entries. It preserves valid legacy wire shapes and entries belonging to other accounts. [Coin retry tests](../../test/core/coins/coins_pending_test.dart) mix malformed entries with valid current-user and other-user entries, then check pruning, preservation, and callable behavior. Existing locking, expiry, account-switch, and idempotency coverage remains.

### A3. Live texture preparation leaked native resources

Baseline `lib/features/live_wallpaper/data/live_texture_preparer.dart:35-65` never disposed the codec or recorded picture. Buffer, descriptor, and image cleanup ran only after successful byte encoding. Decode or crop failures bypassed cleanup.

[LiveTexturePreparer](../../lib/features/live_wallpaper/data/live_texture_preparer.dart) now disposes every acquired native resource through `finally`, including a recorder still recording when an error occurs. The codec is released after its first frame is read. Geometry, JPEG settings, size limits, filenames, and exception messages remain unchanged.

[Preparation tests](../../test/features/live_wallpaper/live_texture_preparer_test.dart) exercise a real small image and a download failure alongside existing geometry coverage. Resource disposal also requires source review of each acquisition and cleanup path. These tests do not claim native allocation measurements or device memory profiling.

### A4. AI responses coerced malformed values into successful records

Baseline `lib/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart:274-280` called `.toString()` on required response fields. A numeric generation ID and map-valued image URL could become a nominally successful record and reach persistence.

The shared mapper in [AiGenerationRepositoryImpl](../../lib/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart) now requires nonempty strings for the ID and image URL. A supplied non-null watermark URL must also be a string. Omitted and null watermark values still fall back to the image URL, and empty strings retain their prior behavior. Invalid responses use the existing `provider_error` failure. Tolerant numeric metadata parsing and charge idempotency remain intact.

[Repository tests](../../test/features/ai_wallpaper/data/ai_generation_repository_test.dart) cover invalid required values and optional watermark values through generation and variation paths, plus valid fallback behavior. This tightens the external API boundary without changing legacy Firestore parsing.

### A5. Share-card lifecycle overrides looked redundant (rejected)

Baseline `lib/core/share/share_card_renderer.dart:149-153` overrides `deactivate` and `unmount` only to call their inherited implementations. This candidate was a false positive. Flutter marks these inherited methods `@visibleForOverriding`, which permits a super call inside the matching override, but not a call from `disposeRoot`. [The renderer](../../lib/core/share/share_card_renderer.dart) retains both original overrides to expose the lifecycle methods locally for its custom root cleanup. Focused analysis and existing share rendering tests verify the retained implementation.

### A6. Known types and required values were obscured

Baseline `lib/features/session/biz/bloc/session_bloc.j.dart:28` stored a `Stream<PrismUsersV2>` subscription as `StreamSubscription<dynamic>`. Baseline `lib/core/persistence/data_sources/session_local_data_source.dart:18` declared a local value `dynamic` although `LocalStore.get` returns `Object?`.

[SessionBloc](../../lib/features/session/biz/bloc/session_bloc.j.dart) now keeps the subscription's model type. [SessionLocalDataSource](../../lib/core/persistence/data_sources/session_local_data_source.dart) uses `Object?` and retains its map check. Existing session and persistence tests plus analysis verify these declarations. `make file-gen` passed for the annotated bloc change and produced no generated diff.

Final analysis also exposed four `cast_nullable_to_non_nullable` findings in [share-service test helper `_origin`](../../test/core/share/share_service_test.dart), at lines 112-115. The helper now asserts that each required origin key is non-null before casting its value to `num`. Missing keys still fail the test, and the expected sharing coordinates remain unchanged. The focused two-test suite and analysis passed. This small typing fix is included in A6 rather than counted as a separate finding group.

### A7. JSON helper documentation gave a false type explanation

Baseline `lib/core/utils/json_utils.dart:5-7` claimed decoded `_JsonMap` objects were not subtypes of `Map<String, dynamic>` and caused release-only cast failures. The private runtime name does not change that Dart contract.

[The helper documentation](../../lib/core/utils/json_utils.dart) now describes its actual purpose: recursively normalizing arbitrary map keys and nested values. The implementation and signature remain because callers use that behavior. This is a comment-only correction verified by formatting and analysis.

### A8. Member-level scanning found unused declarations

A follow-up member scan covered 623 non-generated Dart files, excluding the generated-style JamIcons catalog from handwritten-member decisions. Reference checks included generated Dart, tests, native sources, tools, and repository-wide follow-up searches. A clean top-level declaration scan had missed these narrower members.

The cleanup removes these 13 declarations after caller checks:

- [PrismFeedLayout and PrismBottomSheet](../../lib/theme/app_tokens.dart): `prefetchThreshold`, `loadingIndicatorStrokeWidth`, `errorStatePadding`, `dragHandleWidth`, `dragHandleHeight`, and `sectionTopGap`.
- [CoinsService](../../lib/core/coins/coins_service.dart): the uncalled `spendForPremiumFilter` wrapper.
- [PersistenceKeys](../../lib/core/persistence/persistence_keys.dart): `favoritesSeeded` and its otherwise-unused `favoritesSeededPrefix`.
- [PrismThemeContextX](../../lib/features/theme_mode/views/theme_mode_bloc_utils.dart): `prismIsAmoledDark`.
- [CoinTransactionEntry](../../lib/core/coins/coin_transaction_entry.dart): `isDebit`.
- [StreakRescueResult](../../lib/features/streak/data/streak_rescue_service.dart): `isRestored`.
- [NotificationPrefKeys](../../lib/notifications/notification_pref_keys.dart): `inApp`.

No persisted values, storage records, schemas, or live spending paths were deleted. Framework contracts and live extension members remain. Formatting and focused analysis verify the removals; tests asserting source absence would add no behavior proof.

## Test findings

### T1. A production placeholder list existed only for its test

Baseline `lib/features/live_wallpaper/data/shaders/live_shader_sources.dart:20` declared `placeholders`. Its only caller was `test/features/live_wallpaper/live_shader_sources_test.dart:94-102`; the real replacement method used literal replacements instead. Comparing the redundant list could pass while generated output still contained an unresolved token.

The fix removes the list from [shader sources](../../lib/features/live_wallpaper/data/shaders/live_shader_sources.dart) and checks actual gradient and motion output in [shader tests](../../test/features/live_wallpaper/live_shader_sources_test.dart). Both gradient palettes and motion output must contain no unresolved `{{`. Literal substitutions, ranges, palette differences, precision fallbacks, and smoothstep checks remain.

The member scan also found unused `maxBytes` and `allowedUniforms` metadata constants in shader sources. Both were removed because neither enforced runtime rules or had callers. [Live-wallpaper documentation](../features/live-wallpapers.md) now gives the actual native source limit: at most 64 KiB of UTF-8, enforced by the plugin validator. The plugin compares encoded size against `64 * 1024` with a strict greater-than check.

### T2. A shader validator clone tested itself

Baseline `test/features/live_wallpaper/live_shader_sources_test.dart:15-41` tested the handwritten Dart helper in `shader_contract.dart`, without invoking production Prism code or the plugin's Kotlin validator. Passing those cases could not prove native validator parity.

[The shader suite](../../test/features/live_wallpaper/live_shader_sources_test.dart) removes the helper's self-test group. [The helper](../../test/features/live_wallpaper/shader_contract.dart) remains an approximate lint applied to real generated shaders. Actual Android plugin validation against shared generated fixtures would be stronger proof, but that integration is a separate change. This cleanup does not claim it supplies native validation.

### T3. Theme contrast tests parsed source and pinned obsolete copy

Baseline `test/features/theme_mode/prism_theme_contrast_test.dart:10-27` located the literal declaration `List<Color> _accentColors` in Dart source, parsed hex literals, and pinned 22 colors and 12 themes. This coupled coverage to private syntax without proving the colors were rendered. The page suite also asserted that obsolete `BETA` and `Theme Manager` strings were absent.

[Theme page tests](../../test/features/theme_mode/theme_view_page_test.dart) now pump the real page, traverse the accent picker's lazy horizontal list, and collect colors from selectable rendered semantics. Bounded scrolling checks progress and reaches the end. Those colors are checked against current light and dark themes for primary text, error text, and accent/background contrast. No production accessor or fixed picker count was added.

[The contrast suite](../../test/features/theme_mode/prism_theme_contrast_test.dart) retains default-accent, caption, eyebrow, AMOLED fallback, and stock dark-accent scenarios. The page suite removes the obsolete absence assertions while retaining positive `Themes` and `Done` tooltip assertions. Production UI appearance is unchanged.

### T4. A shader-loading smoke test accepted failure as success

Baseline `test/features/wallpaper_detail/wallpaper_edit/wallpaper_edit_pipeline_test.dart:263-267` asserted only that `loadKernelEffects` completed with a boolean. Both `true` and `false` passed, including shader loading failure.

[The pipeline suite](../../test/features/wallpaper_detail/wallpaper_edit/wallpaper_edit_pipeline_test.dart) removes that test and retains actual rendered-pixel checks. Capability-based skips remain appropriate on backends without shaders. They are not unconditional ignored regressions, and a skipped shader test is not device shader proof.

### T5. Two repository suites duplicated a cache fake

Baseline Pexels test lines 12-34 and Wallhaven test lines 14-36 each declared the same `_NoFeedCache`, despite storing snapshots. [The shared cache fake](../../test/support/fake_feed_cache_local_data_source.dart) already modeled the boundary and now records ordered write scopes.

[Pexels tests](../../test/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl_test.dart) and [Wallhaven tests](../../test/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl_test.dart) use that fake. Fake-only expectations adopt its existing `/` separator. Production cache keys are unchanged. Request sizes, pagination isolation, normalized color keys, refresh fallback, fetch-more failure, orientation, scope isolation, timeouts, and lookup cases remain. The separate Pexels color/query suite protects different behavior and stays.

### T6. Share tests waited real seconds for completed fake futures

Baseline `test/core/widgets/share_button_test.dart:49,83` used a real one-second sleep and a further fake-time pump for each immediate fake callback. Production sharing introduced no matching timer.

[Share button tests](../../test/core/widgets/share_button_test.dart) now settle widget work with `pumpAndSettle`. They retain image, context, card, and cancellation analytics assertions. Other suites' short waits were inspected as candidates but were not mechanically replaced because real debounce and timer behavior needs separate judgment.

### T7. Settings and editor tests assumed fixed filesystem and rendering deadlines

The full local CI run exposed a timing failure in [settings screen tests](../../test/features/session/settings_screen_test.dart), in `the cache size counts tinted wallpapers`. The test polled for 40 intervals of 25 milliseconds. A slow filesystem scan could exceed that one-second window even when cache accounting was correct.

The fix uses a `Completer` signaled by the mocked `listDownloads` platform call after the filesystem scan. A loop yields real events and pumps fake test microtasks until the signal arrives, then pumps the state update. Directly awaiting the signal alone cannot drain the fake-zone microtasks. The handler is removed in teardown, and the test framework's timeout still catches a stuck operation.

The real 2048-byte tinted-file fixture and exact `2 KB of cached images` assertion remain. The focused scenario and complete 42-test settings suite passed. The final full concurrent run also passed this scenario. Production cache accounting is unchanged.

The same full run exposed three bounded-wait failures in [premium editor tests](../../test/features/wallpaper_detail/wallpaper_edit/wallpaper_filter_premium_gate_test.dart) and [editor lifecycle tests](../../test/features/wallpaper_detail/wallpaper_edit/wallpaper_filter_screen_lifecycle_test.dart). Preview helpers allowed half a second for image metadata and decoding. A save helper allowed one second for reading, engine rendering, PNG encoding, directory creation, and writing an export. Those deadlines tested machine speed rather than completion.

The helpers now yield real events and pump fake microtasks until the preview, platform signal, count, rendered text, refunded balance, editor re-enablement, or directory deletion condition occurs. Preview waits fail immediately on a terminal image error. Pure I/O waits do not advance fake time. Once the editor is enabled and its preview decoded, the readiness helper settles finite animations before another export. This also resolves an assumption that a 100 ms pump had finished a 160 ms `AnimatedSwitcher` transition. The lifecycle test drains the existing toast timer with fake time after cleanup; it adds no real delay.

All spending, refund, duplicate-action, disposal, export-pixel, and file-cleanup assertions remain. The two editor suites passed all 11 tests, focused analysis found no issues, and formatting and diff checks passed. Together with the settings scenario, these fixes address four timing failures across three suites without changing production behavior.

## Services and tooling findings

### S1. Pre-push compilation broke a configuration test's fixture path

Baseline `.githooks/pre-push:50-53` compiled Functions tests into a temporary directory. Baseline `functions/src/__tests__/firestoreIndexes.test.ts:9` resolved `../../../firestore.indexes.json` relative to that output. Under `/tmp`, the path resolved to `/firestore.indexes.json`, so module loading failed before assertions.

[The hook](../../.githooks/pre-push) now passes an explicit repository fixture root. [The index test](../../functions/src/__tests__/firestoreIndexes.test.ts) accepts it while preserving the normal build fallback. Validation must run both ordinary compiled tests and relocated temporary output, so a passing normal build alone cannot establish the hook fix.

### S2. Guard searches reported execution errors as clean scans

Baseline `tool/lib/search.sh:11,13` discarded diagnostics and used `|| true`. A nonexistent required path returned success with no findings. The analytics guard independently masked pipeline failures; environment and system-UI guards had the same class of problem.

[The shared search helper](../../tool/lib/search.sh) now normalizes ordinary no-match status 1 but propagates execution errors with diagnostics. [Analytics](../../tool/analytics_raw_usage_guard.sh), [environment](../../tool/env_define_guard.sh), and [system UI](../../tool/system_ui_guard.sh) guards preserve that distinction. System-UI search alternatives share a pattern and generated-file exclusions.

[Behavioral shell tests](../../tool/search_guard_test.sh), wired through `make guard-test` and [local CI](../../Makefile), cover match, no match, missing paths, malformed patterns, and tool failures for both ripgrep and grep paths. Existing guards must also run against the actual repository. The change adds a focused check, not a new process framework.

### S3. Moderation escalation starved reports after the first page

Baseline `functions/src/reportSweeper.ts:30-54` fetched the first 200 open reports, then filtered already-escalated records in memory. Escalation left `status=open`. Once those 200 records had been escalated, every later run fetched and discarded them, leaving later reports untouched.

[The sweeper](../../functions/src/reportSweeper.ts) pages open reports by document ID and cursor until it finds 200 due reports or exhausts results. Missing legacy `escalatedAt` fields still work because the existing predicate remains. No null query, new field, rule, or index was introduced. The cap limits escalations, while scans can read additional pages when earlier reports are ineligible.

[Sweeper tests](../../functions/src/__tests__/reportSweeper.test.ts) place due reports beyond a full page of already-escalated or recent reports and verify they are notified and stamped. A repeated run must not duplicate escalation. [The fake database](../../functions/src/__tests__/fakeDb.ts) supports the document-ID ordering used by the real query. This is a server behavior fix; local tests do not deploy it.

### S4. The dead-code report emitted a comments-only script

Baseline `tool/find_unused_code.dart:618-620,678-681` emitted a script whose helper contained only comments about a hypothetical collapse button. Native HTML `details` elements already supplied disclosure behavior.

[The report generator](../../tool/find_unused_code.dart) removes the script emission and empty helper. It does not add the speculative control. Formatting, analysis, and report generation with retained `details` elements verify this deletion without a test tied to an internal helper.

The related comment in [notificationHelper](../../functions/src/notificationHelper.ts) also now says inbox writes and FCM sends are independent attempts. Calling them atomic contradicted the existing best-effort implementation. Delivery semantics are unchanged.

## Deliberate keeps and rejected candidates

No unreachable production subsystem or dead source file was proven by this audit. The clean top-level scan did not rule out unused members: the follow-up scan found the dead declarations recorded in A8 and T1. The lifecycle wrappers in A5 remain because Flutter's visibility contract requires them. A scanner result alone does not establish safe deletion, especially for deployed exports, native registrations, migration entrypoints, or shipped-client compatibility. Each removed member received caller checks before deletion.

Repository interfaces, use cases, DI declarations, and router barrels have real callers and implement Prism's architecture. Disabled analytics/error implementations support startup and tests. Session/configuration bridges have callers before and after DI registration. Existing asynchronous chains serialize persistence, rendering, downloads, or cancellation and were not removed for their syntax.

Legacy favorites, notification topics, coin payloads, theme migrations, old links, and undated wall-of-day markers serve shipped clients or stored data. Generated JSON maps and callable payload maps are serialization boundaries. The short shared username normalizer has multiple consumers. Migration scripts are explicit command entrypoints, not dead deployed functions; none was run.

Best-effort AI history saves, optional similar-wallpaper failures, offline favorite writes, discard cleanup, and notification partial failures have deliberate behavior. The audit does not introduce speculative retries, an outbox, or broad logging changes. Cloudflare canonical-link metadata remains for existing clients.

Native manifest, privacy, splash, index, and notification-channel tests protect shipped configuration or cross-language contracts. Analytics wire-value tests and enum fallback tests protect external compatibility. Coin payload parsing, account switching, and retry tests exercise real boundaries. Result folding and placement equality tests check behavior beyond construction. Independent scalar image-filter references remain useful pixel oracles. Favorite export tests read an output artifact, not source text. Worker markup assertions check rendered output.

The only identified shader skips are capability-dependent. Native app code and native tests are unchanged. No screenshot or iOS/Android execution is claimed. Production UI appearance is unchanged; device verification remains distinct from widget tests and local analysis.

## Verification

The audit started from `origin/master` at `c5ef0356`. The branch subsequently merged `8609b082` and then `557e85cc`, with the final merge recorded as `ce9bbf6e`. Functions and web dependencies were reinstalled after the dependency updates in `8609b082`. The later master change only corrected a shader-test uniform assignment.

The final full run, `make ci ANALYZE_FLAGS=--no-fatal-infos TEST_FLAGS=--concurrency=4`, passed with **3,006 Flutter tests passing and one existing shader-capability skip**. The preceding run exposed the four timing failures in T7; all four passed in this final concurrent run. No pass is claimed for the interrupted initial run or the earlier failed run. The final log is `/tmp/prism-slop-final-ci-3.log`.

| Check | Result |
|---|---|
| Full local `make ci` with the flags above | Passed; 3,006 Flutter tests passed and one shader-capability test skipped |
| `make format-check` after the final master merge | Passed |
| Local CI guards, including `make guard-test` | Passed; search tests cover both ripgrep and grep |
| Full Flutter analysis | No errors or warnings; four informational findings explained below |
| Dead-code CI gate and `fvm dart run tool/find_unused_code.dart --html --json` | Passed; no unreachable files or unused top-level declarations; HTML retained native disclosure controls |
| `make file-gen` | Passed; no generated diff |
| Cloudflare worker check | 35 tests passed |
| Functions `npm ci`, `npm run build`, `npm run lint`, and `node --test 'lib/__tests__/*.test.js'` | Passed; 413 tests |
| Functions compiled with `npx tsc --outDir` into a temporary directory, then tested with `PRISM_REPO_ROOT` and `NODE_PATH` set as in the hook | 413 tests passed |
| Web `npm ci` and `npx tsc --noEmit --incremental false` | Passed |
| Focused final timing and typing suites | 42 settings, 11 editor, and two share-service tests passed |

The four analyzer notices are the two necessary lifecycle overrides in A5, the ignored local Firebase stub's static-only class, and the existing `Prism` package name. The four nullable-cast notices found during verification were fixed in A6. No lint rule or guard was disabled. The ignored Firebase stub is not part of the change.

The parent reviewed each combined diff and ran the local checks. The final diff check passed, and all 50 relative links in this report resolved. Independent Sol review also examined the implementation, but worker reports do not replace the parent checks. Hosted PR CI, merge status, native device execution, deployment, and live moderation behavior are separate gates. This report claims no device screenshots, deployment, or production result.

Inventory counts can be regenerated with `rg --files lib`, excluding generated Dart suffixes and generated DI files; `find lib/features -mindepth 1 -maxdepth 1 -type d`; and `rg --files test`, separately counting Dart files and `*_test.dart` files. Registration-site counts are textual searches for `test(` and `testWidgets(`, not an executed suite total.
