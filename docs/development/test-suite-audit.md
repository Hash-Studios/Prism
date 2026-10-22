# Test suite audit

This audit keeps tests that catch observable regressions, removes only proven
duplication, and measures coverage against handwritten production code. The
line coverage target is 90%. Reaching 100% does not justify assertion-free
tests or exclusions for inconvenient production code.

## Scope and decisions

The initial structural audit covered all 43 feature test areas. It found
individual redundant cases, but no evidence supports deleting half the suite.
Similar names often cover different layers or failure modes. Keep meaningful
cases at each layer, including financial fallback contracts.

The following cleanup is integrated. Each removal has a specific reason and
a retained assertion for the same contract where applicable.

| File | Change | Retained coverage or reason |
| --- | --- | --- |
| `test/core/constants/profile_links_test.dart` | Remove the test that asserts `minUsernameLength == 3`. | The constant's value is an implementation choice; URL and profile-link behavior remain tested. |
| `test/data/upload/upload_id_test.dart` | Remove the test that asserts `uploadIdLength == 10`. | The generator test still checks requested length, uppercase characters, digits, and exactly one digit. |
| `test/features/onboarding_v2/onboarding_v2_save_error_test.dart` | Remove a source-text AST check for `@RoutePage`. | `test/core/router/onboarding_v2_route_test.dart` checks route construction at runtime. Save-error and retry behavior remains tested. |
| `test/features/user_search/search_screen_test.dart` | Remove a retry test that only verifies the service is called twice. | The retained `a failed search shows an error and retries the same query` case asserts the initial error, two calls for the same query, and a rendered wallpaper after retry. |
| `test/features/user_search/search_tags_test.dart` | Remove a self-comparison and a pinned first tag. | The remaining test checks the curated tag contract without asserting list stability by comparing a list to a copy of itself. |
| `test/haptics_review_navigation/rewards_freeze_haptics_test.dart` | Remove a freeze-sheet pointer haptic case. | `test/features/rewards/freeze_card_haptics_test.dart` retains `Rewards spend freeze entry keeps one tap while opening the purchase sheet`, which taps the same `RewardsSpendSection` entry and asserts one tap haptic, the purchase sheet, and no purchase request. |
| `test/core/coins/economy_config_test.dart` | Combine null and empty remote configuration into one fallback contract. | Assert the shipped prices, rewards, wheel defaults, ranks, flags, and premium policies for both inputs. This financial fallback contract stays explicit. |
| `test/features/daily_chest/chest_domain_test.dart` | Remove pinned tier colors and labels. | Colors are presentation details; labels come from localization. Eligibility and coin balance boundaries remain tested. |
| `test/features/shop/domain/shop_catalog_test.dart` | Remove assertions that prism frame and glow palettes have fixed list lengths. | Catalog selection and frame style behavior remain tested; palette cardinality alone does not establish the user-visible contract. |
| `test/features/library/views/recently_set_row_test.dart` | Strengthen the existing history test instead of keeping a separate broad case. | The replacement checks URL deduplication, input order, an eight-item cap, and the rendered paths. |
| `test/theme/theme_snapshot_test.dart` | Replace broad snapshots of every theme color and text value with role contracts. | The replacement checks display and body font roles, display-size ordering, and status-bar icon contrast across all 12 themes. |
| `test/qa_render/` | Rename optional screenshot entrypoints from `*_test.dart` to `*_render.dart`; add `make test-qa-render`. | Explicit filenames keep the tools runnable and within test-only analyzer scope, while normal `make test` discovery excludes them. Shared QA helpers keep their existing paths. |

Decision rows in `test-suite-decisions.tsv` use `recorded_at` for the UTC time
they were recorded during this evidence review, not historical execution times.
Do not treat the patch size or fewer test declarations as proof of a faster or
safer suite.

## Measurement rules

- Count generated code separately and report missing source records.
- Imported-file coverage is not whole-application coverage.
- Keep emulator authorization and transaction checks as separate evidence.
- Skipped screenshot renders do not prove behavior coverage.
- Record wall time and failures before claiming a speedup. Runs under different
  loads do not support a speed comparison.

Run `make test-coverage` for Flutter line coverage. It runs the behavior
suite, then loads all application libraries in a separate temporary probe. The
probe contributes executable lines to the denominator, but its incidental hits
do not count as behavior coverage. An analyzer check identifies declaration-
only files. Missing executable source records fail the check.

Run `make test-functions-coverage` for Functions line coverage. It uses
pinned temporary `c8@12.0.0` tooling and includes all production sources,
including command-line scripts. Both commands default to a 90% line threshold.
Functions branch coverage is 86.71% and function coverage is 87.86%; the 90%
gate applies to lines.

Flutter and Functions percentages are separate. Native tests, Firestore rules,
website tests, and repository guards remain separate checks. Do not report
those results as Flutter or Functions line coverage.

## Verified results

- Functions final-gate report: 93.09% line coverage, 16,659 of 17,894 lines,
  across 83 production TypeScript files. The suite reported 1,586 passing and
  8 skipped tests.
- Firestore emulator: 194 rules assertions and 8 concurrency tests passed.
- Website: 3 tests passed; TypeScript check passed.
- Repository checks: environment, system UI, Doppler, version sync,
  no-dynamic, Firestore, shape-parse, analytics schema, localization, Cloudflare
  worker (69 tests), and unused-code checks passed.
- Release performance probes: 6 tests passed.
- iOS embedded-framework strip test: blocked on Linux because `xcrun` is not
  available. Native sources are unchanged. No native platform coverage claim is
  made.

## Flutter baseline and final verification

The unchanged baseline at `c147e1fb9` ran 532 test files. It reported 5,337
passing tests, 215 skipped tests, and two failures. Coverage was 40,280 of
45,655 handwritten executable lines, or 88.23%, with no missing records.
The run took 5,259.56 seconds on a shared, heavily loaded host. This is one
coverage run, not a controlled runtime benchmark.

Both failures exposed timing-sensitive tests. The AI history test now checks
that local work finishes before the remote write instead of requiring disk
writes within one second. The favorites export test awaits the share request
instead of polling for three seconds, checks the shared file path, and gives
documents and temporary files separate mocked directories. Its patched full
file passed all 49 tests.

The 16 optional render files contain 210 skipped cases in the baseline.
`make test-qa-render QA_RENDER_TARGET=test/qa_render/creator_progress_render.dart QA_RENDER_FLAGS=--plain-name=creator_zero`
passed both themes after the entrypoint rename and wrote screenshots. The coverage tooling
command, `make test-coverage-tool`, passed all 12 tests.

The render entrypoints remain under `test/qa_render/` as `*_render.dart` files;
their test bodies were not moved to a separate tool directory. `make test-qa-render`
is the explicit route for these optional image checks. `test-suite-decisions.tsv`
records the integrated decisions, including the tool entrypoint rename and the
behavior tests added while addressing measured gaps.

The dependency declarations added for coverage tooling (`analyzer`,
`firebase_core_platform_interface`, and `firebase_remote_config_platform_interface`)
make already-resolved packages direct development dependencies. Their resolved
versions remain unchanged.

The final `make test-coverage` run passed with **5,453 passed, 5 skipped, and
zero failures**. Coverage is **90.08%**, or **41,172 of 45,704 lines**, across all
861 handwritten source files. The source inventory has no missing executable
records or handwritten coverage-ignore directives. The separate inventory
probe passed and contributes no hits to the numerator. The run took 2,127.91
seconds, including the inventory probe and report.

Default discovered cases decreased from 5,554 to 5,458, a reduction of 96.
Passing cases increased by 116 as new behavior tests replaced weak assertions.
Default test files increased from 532 to 537. The final tree includes upstream
test additions through `b8185c574`; 27 of the added passing cases came from those
updates. These counts do not
support a claim that half the suite was worthless. The runs used different host
loads and cache states, so no runtime speedup is claimed.

Four skipped cases require release mode and passed in the separate release
probe run. The remaining image-filter case requires shader-filter support that
this host does not provide. The 210 optional screenshot cases remain available
through the explicit render command.

Final formatting and analysis passed. Analysis reports 301 info findings, with
no warnings or errors. Functions lint passed with 31 warnings in unchanged
files and no errors. Independent review found no blocking issue; its image-error
readiness finding was fixed and the affected tests passed. Production sources
are unchanged relative to the updated base. The guard caught one new fake with
a dynamic map signature; its replacement uses `Map<Object?, Object?>` and passed
both focused tests and the final full run.

The screenshot entrypoint names separate optional rendering from behavior
tests. `make test-qa-render` explicitly runs all 16 render entrypoints.
`QA_PHOTOS` and `QA_OUT` remain environment variables. Fetch sample
photos with `sh test/qa_render/fetch_home_photos.sh`. Screenshot output paths
remain unchanged.
