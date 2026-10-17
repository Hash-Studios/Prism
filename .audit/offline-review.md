# Offline review follow-up

Independent review by Claude Sonnet 5.5 compared the working tree with `72e6b960970663ce3e7d28f45263642baa23eeed`. It read the contract, implementation, decision trail, and available local logs. The original chat transcript was not exposed to the reviewer. Its findings are not a passing test result.

The round sections below preserve their status at each checkpoint. Later proof supersedes an earlier pending or failed result.

## Round 3 findings

| Finding | Disposition |
| --- | --- |
| Category Quick Tile lost live fetch for users without retained originals. | Accepted. Native fix owner restores a bounded online fallback. Verification pending. |
| Collection snapshots can show newly blocked creators. | Accepted. Feed fix owner filters cached reads after block hydration. Verification pending. |
| Pexels and Wallhaven immediate connection failures skip catalog detail fallback. | Accepted. Feed fix owner classifies transport failures separately from permanent failures. Verification pending. |
| Personalized feed waits for optional catalog persistence. | Accepted. Feed fix owner removes persistence from the successful response path. Verification pending. |
| Profile snapshot failure can suppress valid remote data. | Accepted. The first fix guards writes. A follow-up owner guards reads and cleanup races. Verification pending. |
| Catalog and WOTD can read the block set before owner hydration. | Accepted. Feed fix owner adds readiness waits. Verification pending. |
| Login restore exits permanently after a three-second Firebase budget. | Accepted. Startup fix owner waits in the detached restore, without blocking first paint. Verification pending. |
| Bundled starter items can enter cloud favourites and dead public links. | Accepted. Startup fix owner keeps starter actions local. Verification pending. |
| iOS WOTD Shortcut can keep an old mirrored pick while online. | Accepted. Native fix owner tries a bounded current remote pick before local fallback. Verification pending. |
| Android guest entry is not documented. | Documented in the offline guide. Account-only routes retain sign-in guards. |
| Old notification history has no migration. | The old device-global records contain no owner. They are left untouched and not imported into a private account. The guide records this limitation. |
| Favourite replay serializes timestamp fields as strings. | Accepted. Startup fix owner restores known timestamp fields at the Firestore boundary. Verification pending. |
| AI history remote write can stall local owner writes. | Prior owner bounded persistence. The new stalled-write regression still needs a parent run. |
| Catalog records have no age-based takedown signal offline. | Offline cannot discover new moderation. Detail responses that report a missing or moderated item must not fall back. This limitation remains explicit. |

## Round 6 findings and follow-up

The same independent reviewer read the expanded tree. The static verdict was not clean. These fixes are now in the working tree, with final parent-run verification still pending.

| Finding | Disposition |
| --- | --- |
| Category tiles preferred a retained subset even online and matched category names as substrings. | Live lookup precedes retained fallback. Retained candidates require an exact category and verified file. |
| Rotation playlists could point at disposable full-image cache files. | Only verified retained paths replace remote URLs. |
| Short offline budgets could fail slow online requests without useful saved results. | Collections and search use the short budget only with saved results. Detail keeps a normal request budget without saved metadata. iOS image resources retain the 60-second timeout. |
| Remote favourites and block calls held local owner locks. | Separate remote-send ordering from short local revision checks and acknowledgements. |
| Normal upload exit could not keep a retained draft. | Keep draft awaits durable metadata before leaving. Discard remains owner-scoped. |
| RevenueCat configure could race with login. | Serialize SDK setup and reject customer-info application during account transitions. |
| Retained originals could enter iCloud backup. | iOS startup creates and excludes the offline root before Flutter writes descendants. Device policy check remains required. |
| Grid and detail images waited behind local lookup. | Render the remote thumbnail while local lookup runs. Retained images still decode at bounded dimensions. Scroll and hero checks remain device acceptance. |
| WOTD failures without a saved pick looked like an empty successful response. | Return an error when no saved pick exists. |
| Legacy download rows lost display and recovery meaning. | Native-file display lookup is separate from owner acquisition proof. Legacy refund recovery requires an unambiguous legacy identity and an existing, decodable native image, then checks the active owner again. |
| Inbox records could exceed the durable record budget. | Keep newest items under 500 entries and 900 KiB. Skip a single oversized item. |
| Bundled starters reached coin gates and cloud stats. | Starter download is local and free. Detail guards views, sets, reports, and creator blocks. |

The bounded feed cache retains its newest window after deep scrolling, not every historical page. Its cursor follows that retained window. The guide names this limit. Native mirrors validate up to 500 retained paths when rebuilt; no scroll-performance measurement is claimed.

Notification sync uses the durable owner inbox instead of another memory-first result cache. The owner-and-audience sync gate still deduplicates concurrent work and applies a 45-second cooldown. This avoids advancing the durable watermark from a stale in-memory query result.

AI transfers have a 30-second budget. Native photo-save success does not depend on optional retention. Online history combines the remote page with pending local records, not old synced records. Parent-run verification remains pending.

## Final comment pass

Luna's round 11 comment review found 11 redundant comment blocks and no added lint suppressions. Round 12 removed those blocks from nine files. No comments were restored. Injectable's `@ignoreParam` annotations are not lint suppressions.

The payment checks already use separate synchronous acquisition and asynchronous verified-native callbacks. Exact acquisition and legacy recovery have separate regression tests. No additional abstraction was added for the deleted comments. Optional cache writes remain explicit, scoped `try` operations. No new constraint enforcement is pending from this pass.

## Round 11 findings

Claude Sonnet 5.5 found no money or owner-isolation bypass in its static review. It found the following integration defects. The parent confirmed the paths and assigned three file-owned repair streams. Tests remain a separate gate.

| Finding | Disposition |
| --- | --- |
| An empty thumbnail resolves to `File('')` and masks the full-image fallback. | Accepted. Use the same effective source for lookup and rendering. Keep the missing-thumbnail regression. |
| A tile test prohibits the thumbnail request that the pending-lookup fix now requires. | Accepted. Assert pending thumbnail and subsequent retained image, not an obsolete implementation detail. |
| Prism search has a short budget without useful saved results. | Accepted. Preserve slow online success without a saved fallback. |
| Adjust resolves the original without busy feedback. | Accepted. Pair busy start and reset around resolution. |
| A bundled starter still records a cloud set action. | Accepted. Guard the remaining successful-set path. |
| Inbox bounds repeatedly encode each retained prefix. | Accepted. Count the exact JSON envelope once and each item once. No measured speedup is claimed. |
| Empty favourites, WOTD archive size, and inbox owner fallback have inconsistent boundaries. | Accepted. Respect authoritative empty server results, the actual feed-record budget, and user-ID-or-guest inbox ownership. |
| Several service fixtures always supply cache bytes. | Added explicit service and share cache-miss cases. Positive fixtures remain useful for native-status and rendering tests. |

An acquisition remains valid after premium lapses when the same owner still has the exact acquisition record and a valid local original. The app does not grant new premium capability. Legacy refund recovery can refund an old pending entry when native verification fails or its identity is ambiguous.

Android JSON and bitmap assertions now live in the existing instrumentation suite, with a positive PNG case. Plain JVM tests retain the four platform-independent category fallback cases. Instrumentation compilation and runtime device execution are separate checks.

## Round 15 follow-up

Claude Sonnet 5.5 read the repaired paths and selected money and account boundaries. This was a targeted static review, not a review of every changed file or a passing test run.

| Finding | Disposition |
| --- | --- |
| Adjust passes a resolved cache path to the studio and loses the original history identity. | Accepted. Preserve the original URL through the studio while retaining busy feedback. |
| The free starter download returns before a selected tint is prepared. | Accepted. Prepare the variant before the starter save and keep its source as the saved image. |
| All or partial WOTD lookup failures can bypass or shrink a saved archive. | Accepted for transport failures. Do not restore an authoritative missing or moderated item. |
| A bounded favourites read leaves its underlying listener active after timeout. | Parent finding. Cancel the metadata subscription on all completion paths. |
| Adding the inbox watermark can cross the feature byte cap. | Parent finding. Apply the same envelope bound after the watermark changes. |

The focused round 15 run passed 196 tests and failed 15. The failures include stale tombstone ownership, non-writable test paths, and obsolete concurrent-send assumptions. These results do not establish a green integration gate. Dedicated fixture repairs preserve the original assertions about history, content URIs, owner isolation, and permanent rejection.

The Android debug APK and four category JVM tests passed. The full native round 13 gate failed inside Android lint on Java 17 with `List.removeLast`. Hosted CI uses Java 21. The parent will use the matching host JDK instead of disabling the lint detector.

The platform and inbox fixture rerun passed all 41 tests. The parent also confirmed the deleted account-cleaner comment described an obsolete subset of the cleanup steps. Its deletion is intentional; the current named step list is the executable source of truth.

## Final boundary repairs

The parent confirmed the unavailable-original error with a failing test before the fix. Set now distinguishes missing local bytes and socket failures from corrupt-image failures. The round 18 platform and favourites run passed 60 tests and failed the same two favourites timeout tests. This is not a green gate.

Two listener implementations failed those timeout assertions. A fresh Luna owner now has the filtered-test slot and must identify the stalled stage before another correction. The parent rejected the unproved assumption that listener cancellation explains the failures.

The final action repair preserves the original URL when opening the position studio and prepares a selected starter tint before saving. The archive repair carries transiently unavailable rows forward and removes confirmed missing rows from durable fallback. Its cached path waits for block-list hydration. The parent also found that legacy feed migration bypassed the 512 KiB snapshot limit. Read and migration now apply the same cap as new writes.

These repairs have regression tests. Their integrated verification and the independent follow-up remain pending.

## Round 19 follow-up

Claude Sonnet 5.5 confirmed the Adjust identity, starter tint, unavailable-original error, and upgraded feed-cap changes within its targeted read. It found a stale `dart:io` import after the Adjust change. The parent removed it.

The reviewer also found three daily-pick gaps. Authoritative missing results did not invalidate the saved today record. A transient wall lookup did not reuse a matching saved pick. Mixed archive failures could skip removal of rows confirmed missing. A fresh Luna owner is repairing those paths and adding restart regressions.

The favourites diagnostics found that the read waited for cancellation cleanup after the timeout had already fired. Requesting cancellation without awaiting that cleanup passed both filtered tests. The parent added error handling and a cleanup-failure regression before the next run. This result does not establish a full green gate.

The reviewer's claim that the round 18 log covers only favourites is incorrect. The log includes `test/core/platform/wallpaper_service_test.dart`, including unavailable-original, socket, and corrupt-image cases. The parent command named both files. The combined result remains 60 passed and 2 favourites failures, not proof for the later action, archive, or feed-cap edits.

The repository guards passed after the parent replaced a `List<dynamic>` test declaration with `List<Object?>`. Supported Swift build and Swift 6 type checks passed on Linux. The Xcode project file passed `plutil`. Full iOS and device acceptance remain separate.

## Round 21 follow-up

Claude Sonnet 5.5 confirmed the bounded favourites cleanup and its error regression. The review found that a cache snapshot still waits eight seconds for a server result. A fresh Luna owner is adding a short cache grace period while keeping server-confirmed empty results authoritative.

The daily archive's blocked-result fixture now publishes its completed snapshot to the fake repository cache. The next run exposed a real empty-result gap. A saved archive with only blocked creators must produce an empty visible result, without treating an unrelated empty cache as proof that no picks exist.

The review also traced moderation to permission-denied under the current Firestore rules. Non-transient wall failures must invalidate saved picks, including archives without a separate missing row. Pointer errors must allow fallback only for transport failures. The daily owner is adding these restart regressions.

The parent confirmed that a plain Firestore query does not expose whether an empty or partial response came from the SDK cache. The daily archive will use the existing metadata stream instead. Cache-only results must not erase its durable archive. This does not change Firestore rules or grant access to remote content.

The Android Java 21 gate passed JVM tests, lint, and instrumentation APK compilation. Boundary round 20 passed all 70 Flutter tests. Analysis round 21 passed with 117 informational findings and no errors or warnings. The action round 20 and daily round 22 were not green. Their fixture repairs do not substitute for a final settled-tree gate.

The review's old-pointer observation concerns pre-existing Firestore cache behavior. Only the app-owned saved-today fallback enforces a same-day check. The guide now distinguishes that guarantee from a last fetched SDK pointer. A blocked creator can also require a fresh lookup after an unblock if its public snapshot was removed. No offline moderation discovery is claimed.

## Read-boundary convergence

The final favourites repository run passed all 31 tests. SDK cache events now allow a 500 ms grace period for a server response. Reads without an SDK cache event retain the eight-second bound. Cancellation does not hold the result open, and cleanup errors remain observable.

The daily archive now reads query metadata. A cache-only empty or partial query cannot replace its durable archive. Raw archive rows remain separate from caller-visible block filtering. Permission failures invalidate saved today and archive rows. These changes have new restart regressions, but the settled-tree gate remains pending.

The download fixtures now assert the retained file returned by the asset store, not its input file. The initial retain stalled because the asset store's write queue originated in the widget's paused fake-async zone. Constructing the store in `tester.runAsync` lets the test reach the save assertions. Completion signals and toast cleanup remain part of fixture verification.

Claude Sonnet 5.5's round 26 review confirmed the daily archive and favourites repairs within its narrow scope. It found that an unchanged Firestore query did not request metadata-only server updates. The watcher now requests those updates only for metadata consumers. Plain data listeners keep their prior subscription mode. WOTD cancellation is now non-blocking, with timing and stalled-cleanup regressions. The warm-cache case remains part of device acceptance.

The round 29 delta review closed both round 26 findings. It found no remaining concrete blocker in the watcher and WOTD files it reviewed. This is a static review, not a full-tree or runtime verdict.

## Final integration pickup

The round 31 focused run passed 120 tests and failed four. The Firestore stream emitted both expected records, but its test compared list identity inside records. Structural field matchers preserve the content and metadata-order checks. The download failures concern fake-async store construction and pending completion timers. No production behavior was changed for these fixture repairs.

Master advanced to `48ac7cb1a` with the share-preview changes from PR 490. Merge `1d158a291` combined those changes without conflicts. The next full gate covers the shared detail, favourites, settings, and link paths.

Claude Sonnet 5.5 found no merge-induced defect in those four files. It did find two starter share entry points that the earlier starter guard missed. Long-press sharing and favourites could send temporary file paths to the public link service. The link boundary now returns the public app landing page for source-qualified starters without requesting a short link. Multi-favourite text replaces starter paths with the same landing page. Ordinary wallpapers keep their preview metadata and canonical links. The focused share suite passed all 48 tests, including actual clipboard and mixed-selection share text assertions.

The parent stopped full gate 33 at 297 passing Flutter tests to apply that repair. Its exit code was 130, and its interrupted loading error is not a product failure or a passing gate. Download round 32 passed all 72 tests. The final full gate must run again after the starter share repair.

## Gate 35 repair checkpoint

Claude Sonnet 5.5 closed the starter-sharing finding in its narrow follow-up. It confirmed the source-qualified identity guard, public-request bypass, and safe single- and multi-share text. It did not provide device or full-suite proof.

Gate 35 passed the static checks, including analysis with 116 informational findings and no errors or warnings. The Flutter run reached 2,531 passes, one skip, and 30 failures before all four test slots stalled. The parent interrupted it with exit code 130. Its shutdown errors are interruption artifacts, not additional product findings. This is not a completed or green gate.

The four stalled files were upload entry, collections grid, downloaded detail, and clock overlay. The repeated upload test label was the reporter's oldest active test, not proof that it passed. The parent corrected that earlier status claim.

Readonly Luna diagnostics traced several failures to stale fakes and asynchronous fixture assumptions. AI fakes omit the new local-history method. Profile tests share a single-subscription fake stream and cancel before durable I/O completes. Upload setup mixes fake-zone construction with real-zone writes. Collections tests retain module state or seed the wrong provider type. Repairs must keep the owner, money, block, cancellation, and retained-file assertions. A possible profile cleanup stall also needs a focused regression before a production change.

Three disjoint Luna owners now repair profile, native/upload, and AI/category tests. Only one owns the Flutter compiler at a time. The later downloaded-image and wallpaper-action failures remain in the repair queue. A fresh full gate must cover the final tree.

The repaired profile fixtures passed 16 tests and failed three in focused run 41. Both cancellation before the remote stream is consumed and cached-first restart reads stalled. The new bounded cancellation regression also failed. This confirms a production cleanup defect, rather than only fixture drift. The profile owner now has the exact repository and test file for a minimal lifecycle repair. AI/category and four detail fixture repairs are ready for focused tests. The action-bar acquisition tests still need to exercise the real download flow instead of invoking its notification callback directly.

The first profile correction removed the blocking controller-close await. It fixed cached-first reads but left cancellation during the initial cache read stalled. The final correction observes cancellation at the subscription boundary. The owner reports all 20 profile tests passing. The native/upload owner's earlier test runs failed or stalled before its final edits; those runs do not verify the final fixture changes.

Parent run 44 reached 118 passes and 11 failures before interruption with four stalled files. Its timeout wrapper returned zero despite the failed and interrupted log. That exit code does not establish success. Shortcut setup called shared preferences before installing its fake. Upload, collection refresh, and wallpaper action fixtures still waited across paused fake-clock boundaries. Dedicated owners repair those waits without dropping their behavior assertions.

Claude Sonnet 5.5 reviewed the exact profile rewrite and found no concrete lifecycle or owner-isolation defect. It ruled out the suspected fake-watcher readiness gap. The parent run still timed out while waiting two seconds for profile events that include a flushed disk write. A slow first write under load is plausible but unproved. The review remains inconclusive until repeated parent runs pass. Cancellation counters establish watcher cleanup; a later event sent to an unsubscribed broadcast fake is not independent proof of ignored late writes.

Native fixture round 45 completed with six passes and four failures. All four upload tests passed, including retained-draft resume without reselecting its deleted picker source. The remaining shortcut failures occur after its first iOS case. The parent traced the persistent future to the nested native-path store. Its continuation belongs to the previous widget test's stopped fake clock. The repair will retain the five iOS scenarios in one test clock instead of adding production reset code. This diagnosis is not a passing test result.

## Gates 48 and 49

Generation round 47 passed and produced no generated-file diff. Parent run 48 passed all 20 profile tests, including cancellation and durable restart reads. It then reached 166 passes and ten failures before the action-bar test stalled after native save. The parent interrupted it with exit code 130. Collection refresh, set-flow feedback, and retained-image rendering still require fixture repairs. No full gate passed.

Parent run 49 passed all 26 tests across profile, shortcuts, and upload entry with exit code zero. The five iOS shortcut scenarios now share one widget test clock, with their original assertions intact. Android still has a separate no-write test. No production queue reset was added. The retained-upload case still deletes the picker source and resumes its retained copy without opening the picker.

The profile has now passed two parent runs after the subscription-boundary rewrite. Only the first disk-backed profile/null event wait uses the ten-second disk-observation budget. Watcher readiness and the cancellation regressions retain their two-second bounds. These runs do not prove the cause of the earlier slow write or establish full-suite success.

## Gates 51 to 54

All 23 action-bar tests passed in the focused worker run and again in parent run 51. Parent run 51 still failed because two other files did not compile. An explicit nullable type on `tester.runAsync<File?>` fixed those two compilation errors. The action tests retain their one-spend, tinted-byte, original-identity, owner-isolation, and failed-save checks.

Parent render run 52 completed with 46 passes and six failures. Retained-image tests reached missing path-provider plugins and failed to find the expected local image. Network preview tests also failed to find their expected image widget. These are unresolved runtime failures, not evidence that the offline rendering contract works. A fresh Luna owner has the two render fixtures and the exclusive compiler slot.

Parent set-and-refresh run 53 completed with 18 passes and one failure. Both accent actions and the observed collection refresh passed. The remaining landscape safe-area test failed because the shared test helper replaced its explicit view dimensions. The new surface override is limited to the accent test. Parent run 55 verified the correction with all 19 tests passing and exit code zero.

Render worker 53 completed with 48 passes and four failures. A direct real-zone resolver call returns the retained file, but that alone does not prove widget rendering. The parent found that detail mounts its network image while the retained lookup is still pending. A new owner now has the two widget sources and their fixtures to defer that fallback and prove actual local rendering. Claude Sonnet 5.5 is checking the remaining failure causes independently.

Claude Sonnet 5.5 independently confirmed the premature detail network fetch. The placeholder repair leaves the existing network image as the fallback after a completed local lookup. Clock preview already has that ordering and does not need a production change. The review also confirmed that fixture waits can block a frame needed to start their own completion signal. Its explanation that six pumps cannot complete the nested disk operations remains an inference until measured. The repaired tests must wait for the exact retained image or cache signal, and they must observe `getFileStream` on the actual image cache managers.

## Parent run 57

The render worker passed all 52 tests after the main-image placeholder and fixture fixes. The parent rejected its change to an empty thumbnail in the retained-detail fixture. That avoids the color swatches' existing network path instead of proving that the full detail works offline. A new owner must share the retained original with every swatch and restore a nonempty thumbnail in the regression.

Parent run 57 completed all 15 focused files with 226 passes and two failures. The profile badge-mapping test timed out after two seconds while observing events that include durable writes. The existing ten-second disk-observation budget now applies consistently to profile events and restart reads. Explicit watcher and cancellation bounds remain two seconds, including cached-first cancellation. The other failure checks image tint before the newly gated image has resolved. Its fixture must wait for the actual image without weakening the hue assertion. These corrections still require parent verification.

## Frozen gate 65

The swatch regression now keeps its nonempty thumbnail and two palette colors. It checks four retained-file images, including all three swatches, their hue modes and selected identity, and no requests through either image cache manager. The worker's full downloaded-detail file passed all eight tests.

Parent run 62 completed with 226 passes and two action-bar finder failures. All 20 profile tests and the restored retained-image regression passed. The finder matched the main thumbnail and two swatches. The parent limited it to the `Wallpaper` semantics subtree. Parent run 64 then passed all 23 action-bar tests. No hue assertion was removed.

The earlier gates 48 and 49 description of only one disk-event timeout is superseded by the parent 57 correction. All disk-backed profile event waits now use the existing ten-second budget. Watcher readiness and cancellation bounds remain two seconds, including the cached-first cancellation regression.

Claude Sonnet 5.5 found no new blocker in the final production and test delta. This was a static review, not runtime proof. It confirmed that no new code comments were added and the earlier removals were not restored. It flagged a possible extra full-size image decode for retained swatches, the new pending placeholder's flicker risk, and cosmetic differences in starter share text. These remain device-review considerations, not measured regressions. The pump-count explanation remains inferred.

Full gate 65 passed static checks and reached 506 Flutter test passes without a reported failure. The parent interrupted it after discovering that master advanced to `4fd037348`, the coin-economy v2 merge. This is a partial result, not a full gate pass.

## Latest-master integration 66

The new base changes 315 files since `48ac7cb1a`, including startup, coins, entitlements, wallpaper detail, and native entry points. The current repair delta is preserved in a commit before a normal merge. Three Luna reviewers inspect disjoint economy, native, and catalog overlaps. The merged tree requires fresh generation and verification. Hosted CI and the user's device round remain pending.

The three text conflicts preserve offline download acquisition checks, cancellation-safe cached profiles with the new cosmetic fields, and both AI fixture changes. The parent also found an undefined startup readiness variable from the automatic merge. Its owner restored the bounded readiness result and deferred economy-config loading when Firebase completes later.

The native review found an ownerless persisted auto-rotate pass. The catalog review found that the new Draw, Drops, and Leaderboard repositories depend on opportunistic SDK cache and lack app-owned deadlines and saved snapshots. These are integration work, not verified offline journeys yet. Separate Luna owners implement pass isolation and bounded saved reads without replaying purchases.

Native Android gate 66 passed JVM tests, lint, and instrumentation compilation on the merged native files. Supported Swift core build, strict fallback typecheck, and project-file lint also passed. Logs are `/tmp/prism-offline-android-native-66.log` and `/tmp/prism-offline-swift-66.log`. Device discovery reported no available simulator or emulator, so no device runtime result is claimed.

## Economy integration review 68 through 73

The parent rejected the initial private-economy snapshot patch. Its revision field did not reach the restore parser, its inventory representations disagreed, and a failed cache write could hide an acknowledged mutation. Cleanup could also race an in-flight write. Worker 70 repaired parts of this delta but explicitly did not verify offline bootstrap, permission and timeout behavior, or disk failures.

Claude Sonnet 5.5 independently identified stale equal-revision overlays, cached absence mistaken for confirmed server absence, and refund retry initialization skipped after a root-read timeout. The parent also traced local restoration behind Firebase readiness and rotation entitlement updates that do not observe a late pass restoration. These findings are open until the focused repairs and their tests pass.

Luna 71 owns local-only restoration, private economy revision and mutation recovery, and service tests. Luna 72 owns rotation pass updates and owner-specific deletion cleanup. Luna 73 owns a shared bounded metadata-confirmed read and the new Draw, Drops, and Leaderboard consumers. A cached empty snapshot must not erase durable saved content. Private writes and cleanup must serialize for the same owner without blocking another owner.

No full Flutter gate has passed on this merged tree. No PR or hosted result is claimed at this checkpoint.

## Integration proof 74 through 84

Generation 75 passed. The rotation and cleanup focused run passed all 39 tests. Parent focused run 78 completed with eight failures, including three generic-stream compile failures. This is not a green gate.

Claude Opus 5.5 confirmed two money-recovery regressions. Early account-switch returns skipped captured-owner ledger and refund bookkeeping. A catch around critical refund persistence could remove the only durable recovery record. The repair must preserve the existing pending-download assertions, not weaken them. The reviewer also found that strict newer-only private revision checks can hide fields omitted by a partial quest reply. A late missing read can erase a newly acknowledged pass. These fixes require fresh service-level proof.

Claude Sonnet 5.5 requested runtime proof for document-ID filters and ticket query authorization. The tracked adapter now maps document-ID filters to `FieldPath.documentId`, with a regression. Parent rules run 82 disproved the inferred requirement that an exact owner ticket query without a uid filter must fail. It returned 200. The explicit uid filter remains, and wrong-owner queries remain forbidden. The corrected run 83 passed the complete rules smoke suite. It also proved that an exact owner query on `usersv2/{uid}/private/economy` succeeds and another owner's query fails. No rule changed.

Malformed saved Drop records now parse independently, so one bad row cannot prevent later successful refreshes from persisting. Parent catalog run 84 passed all 51 tests, including that regression, the document-ID adapter, confirmed-server reads, and saved Draw, Drops, and Leaderboard repositories.

Master advanced to `65f463dc5` with Studio Telegram posting. Normal merge `222f5f844` integrated its five files without conflicts or overlap with the offline repairs. The feature diff does not remove those upstream files. The next full gate uses this merged tree.

## Economy repair 80 through 92

The money-recovery repairs retain captured-owner ledger and refund bookkeeping after an account switch. Critical refund persistence errors propagate instead of deleting the only recovery record. Private snapshots accept an equal-revision full server read when no acknowledged local mutation occurred during that read. A separate root display snapshot retains XP and equipped cosmetics without granting coin authority.

Run 85 reached 216 passes and one failure before the parent interrupted the stalled pass widget. The pending-purchase failure showed that cleanup must invalidate operations even before the economy mirror initializes. Worker 87 added this guard and deterministic pass, live-style, and grace-download race coverage. Spend acknowledgement advances the mutation marker before asynchronous bookkeeping.

The pass widget fixture now mocks its toast channel and awaits the actual purchase and toast endpoint outside the fake clock. Production UI did not change for that repair. Run 90 passed all three widget tests.

Independent Claude Sonnet 5.5 review 86 identified permission denial mistaken for proof of private document absence. Worker 91 corrected this path. Only a confirmed server absence clears private economy state. Permission errors retain last-known inventory and passes, with a restart regression. The guide records this policy separately from public catalog metadata invalidation. Combined economy run 92 passed all 223 tests with exit zero.

Full local gate 94 passed formatting and early guards, then stopped at one analysis error. The upstream QA-render profile repository fake did not implement the offline cleanup interface method. Worker 95 owns that fixture repair. The full gate is not yet green.

Worker 95 added the missing no-op cleanup method to the render fake, without changing assertions or production behavior. Gate 97 passes analysis and guards and has reached the test suite. Independent Claude Sonnet 5.5 closure review 93 found no concrete blockers in the repaired economy paths and no added narration comments. Its live-read notes predate gate 94's failure and the later documentation updates. The final gate result below, once recorded, supersedes those interim notes.

## Evidence limits

The inherited trail contains estimated timestamps, with append-only correction rows. Several early rows name local `/tmp` logs that are not portable PR artifacts. Later committed tests and hosted checks must carry the final proof. The foundation commit proves its six files only. The later implementation commit and master merge preserve the wider integration tree but do not replace its full verification.

No device screenshots or runtime results have been claimed. The user owns the iOS and Android verification round before merge. Linux cannot run the iOS suite that imports ImageIO. Local checks, hosted checks, and device acceptance remain separate gates.
