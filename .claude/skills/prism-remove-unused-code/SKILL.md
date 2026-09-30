---
name: prism-remove-unused-code
description: Find and delete unused code (unreachable files, dead public symbols) from the Prism Flutter app, then refresh tool/find_unused_allowlist.json (and its notes file tool/find_unused_allowlist.md) so the codebase stops getting flagged. Use whenever the user asks to clean up, prune, tree-shake, dead-code-strip, or "remove unused code from" a Prism area (e.g. lib/features/wallpaper_upload, lib/core/analytics). Use it without asking when they ask to run the cleanup across "the whole app", "everything", or "all features"; in that case, dispatch one subagent per lib/features/<name> (and one for the shared lib/core, lib/data, etc. folders) and run them in parallel. Also fires on phrases like "what's dead in lib/features/X", "remove dead methods", "remove unused widgets", "delete unused API endpoints", or any variation implying finding-and-deleting code the static scan can prove is unreferenced. Do NOT use for general refactoring, for cleaning *generated* files (*.g.dart/*.freezed.dart/*.gr.dart), or when the user wants to investigate dead code without deleting (use `make find-unused-html` directly for that).
---

# prism-remove-unused-code

Dead-code cleanup for the Prism Flutter app. Drives `tool/find_unused_code.dart`,
decides what to delete vs. what to allowlist, and leaves the app in a state
where `make find-unused-ci` is green without anything dead-but-still-on-disk.

## The mental model

Prism is a single Flutter app, not a multi-package workspace: everything
lives under `lib/`, with a `packages/cloud_functions` folder that is a
vendored copy of the `cloud_functions` Firebase plugin (third-party code,
never a cleanup target). So "per package" in this skill means **per
`lib/features/<name>` folder**, or **per top-level `lib/` folder**
(`lib/core`, `lib/data`, `lib/auth`, `lib/analytics`, `lib/theme`,
`lib/notifications`, `lib/global`, `lib/logger`) when the user doesn't name
a feature.

`tool/find_unused_code.dart` reports two kinds of findings (it does not
check pubspec dependencies: Prism has one root `pubspec.yaml` for the app,
not per-package manifests):

1. **Unreachable files**: `.dart` files under `lib/` that no import/export/
   part chain reaches from `lib/main.dart`.
2. **Unused public symbols**: top-level classes, mixins, enums, extensions,
   typedefs, and simple top-level functions/getters that no *other* file
   references by name. It does **not** tree-shake transitively and it does
   **not** understand `part`/`part of` beyond linking a part back to its
   parent. Read the findings as leads, not proof.

The job of this skill is to **delete what is genuinely dead** and
**allowlist what is load-bearing-but-statically-invisible** (extension
methods invoked implicitly, DI/router-registered classes, test-only
interfaces). After processing an area, its entries in
`tool/find_unused_allowlist.json` should only be genuine false positives,
and `tool/find_unused_allowlist.md` should explain why each one is kept and
who owns it.

## How to invoke

- **Single area**: the user names one feature or folder. Run the workflow
  below in this session for that area only.
- **Whole app**: the user says "everything", "the whole app", "all
  features", or doesn't name an area. **Dispatch one subagent per
  `lib/features/<name>` folder, plus one for the shared `lib/core` +
  `lib/data` + `lib/auth` + the rest of top-level `lib/`, all in the same
  message so they run in parallel.** See "All-areas mode" below.

# Single-area workflow

Replace `<area>` with the target path prefix throughout (e.g.
`lib/features/wallpaper_upload` or `lib/core/analytics`). Working directory is the
repo root (`/Users/codenameakshay/Development/codenameakshay/Prism` or the
worktree you were given).

## Step 1: Pull the raw findings for `<area>`

Bypass the allowlist by reading straight from `--json` output, then filter
to just this area's files with Python (the underlying `dart run` process
can print extra lines before the JSON, so locate `{`/`}` rather than piping
straight to `jq`):

```bash
fvm dart run tool/find_unused_code.dart --json > /tmp/prism_dead.json 2>&1
python3 - <<'PY'
import json
AREA = '<area>'  # e.g. 'lib/features/wallpaper_upload'
with open('/tmp/prism_dead.json') as f:
    s = f.read()
d = json.loads(s[s.find('{'):s.rfind('}') + 1])
fh = [f for f in d['unreachable_files'] if f.startswith(AREA)]
fs = {f: syms for f, syms in d['unused_symbols'].items() if f.startswith(AREA)}
print(f'UNREACHABLE FILES ({len(fh)}):')
for f in fh: print(' ', f)
print('UNUSED SYMBOLS:')
for f in sorted(fs):
    print(' ', f)
    for s in fs[f]: print('   -', s)
PY
```

Track every finding in a TodoWrite list so nothing slips.

## Step 2: Triage unreachable files

For each file, **grep before you delete**. The scan only follows the
*primary* URI of conditional imports and can miss a late-bound `part`.

```bash
# Does the file's main public symbol appear anywhere outside the file?
grep -rln "\bMainPublicSymbolName\b" lib test --include='*.dart' 2>/dev/null

# Does anyone import this file's path?
grep -rln "package:Prism/<rel-path-after-lib>" lib test --include='*.dart' 2>/dev/null
```

Decision rules:

- **One-line re-export shim** (`export 'package:...';` only): delete on
  sight.
- **Zero external symbol or path references**: `rm` the file.
- **References only in `test/`**: the scan builds its reachability graph
  from `lib/main.dart`, not from tests, so a file only a test imports still
  counts as dead app code. Delete the file and its now-orphaned test.
- **References exist outside the file, in `lib/`**: investigate. The scan
  likely missed a `part`/`part of` pair or a conditional-import branch.
  Don't delete blindly.

If deleting empties a directory under `lib/`, `rmdir` it too (and remove the
matching now-empty directory under `test/` if one exists).

## Step 3: Triage unused symbols

For each flagged file, check whether **every** top-level public symbol in it
is dead. If yes, delete the whole file (after the Step 2 grep check). If
only some are dead, remove just those declarations.

- **Don't touch imports yet.** A type referenced only by the removed symbol
  may still be used elsewhere in the file. After all symbol removals, let
  `fvm flutter analyze` surface newly-unused imports and clean them in one
  pass.
- **Don't chase the transitive cascade** in this run. The scanner has no
  transitivity, so removing one symbol may make a helper it called newly
  dead. Leave that for the next pass; it will surface on a re-run.
- **Watch the false-positive shapes already known in this repo** (see
  `tool/find_unused_allowlist.md`): extension members invoked implicitly
  (`value.someExtensionGetter`), `MixpanelClient`-style interfaces that are
  test-only, and analytics enum extensions generated for completeness. Don't
  delete these: allowlist them (Step 5) unless you can prove they truly
  have zero call sites, including in generated analytics code.
- **`@RoutePage`/auto_route screens and DI-registered classes** can look
  unused because registration happens via annotation/build-time codegen,
  not a plain reference. Grep the router config and `*.gr.dart` before
  deleting a screen widget.

## Step 4: Update the allowlist

`tool/find_unused_allowlist.json` is hand-maintained, not auto-generated:
there is no seed command. After deleting genuinely dead code:

1. Re-run the scan (Step 1's `find_unused_code.dart --json`) to see what's
   still flagged for `<area>`.
2. For anything left that is a real false positive (extension usage,
   DI/router registration, test-only interface), add it to
   `tool/find_unused_allowlist.json` under `unreachable_files` (a plain
   array of paths) or `unused_symbols` (a map of file path to array of
   symbol names), matching the existing JSON shape exactly.
3. Remove entries from the JSON that no longer appear in the report (dead
   allowlist entries mean the code was already deleted or renamed).
4. Update `tool/find_unused_allowlist.md` with a one-line reason and an
   owner for any new entry, following its existing "Why these appear
   unused" / "Owners" sections.

If a file or symbol you deleted was allowlisted, delete its entry from both
files. Don't leave a stale reference.

## Step 5: Verify

```bash
make format-check
fvm flutter analyze --no-pub --no-fatal-infos
fvm flutter test
make find-unused-ci
```

- `format-check` catches formatting drift from your edits.
- `analyze --no-fatal-infos` must succeed (pre-existing infos in this repo
  are otherwise fatal per `AGENTS.md`).
- `flutter test` must stay green. Deleting a file used only by a test you
  missed will show up here.
- `find-unused-ci` runs `find_unused_code.dart --json` and diffs it against
  `tool/find_unused_allowlist.json` via
  `tool/validate_find_unused_allowlist.dart`; it must exit 0 with no "New
  dead code not in allowlist" and no "now stale" section left unresolved.

If `find-unused-ci` reports new findings (a transitive cascade from your own
deletions), repeat from Step 1 for those files. Two passes is usually
enough, don't iterate indefinitely.

## Step 6: Report

Summarize what changed: files deleted (with count), symbols removed (with
qualified names), allowlist entries added or removed (with reasons), and any
judgment calls made. Use file paths so the user can jump to them.

# All-areas mode

When the user wants the whole app processed, **do not loop sequentially**.

## Step 1: Enumerate areas

```bash
ls lib/features
ls lib | grep -v features
```

Each `lib/features/<name>` is one area. The remaining top-level `lib/`
folders (`core`, `data`, `auth`, `analytics`, `theme`, `notifications`,
`global`, `logger`, plus `main.dart`/`env`) are grouped into one more area
since they're smaller and more interdependent than a feature.

## Step 2: Spawn subagents (one per area, all parallel)

Use the `Agent` tool with `subagent_type=fast-worker`. **Put every subagent
call in the same message** so they run concurrently. Each prompt must be
self-contained:

```
Run the prism-remove-unused-code skill's single-area workflow for
<area> only, in /Users/codenameakshay/Development/codenameakshay/Prism
(or the worktree you were given).

Constraints:
- Only touch files under <area>/ (and its mirror under test/<area-without-lib->/).
- Do NOT edit tool/find_unused_allowlist.json or tool/find_unused_allowlist.md
  (the orchestrator reconciles the allowlist once at the end from all
  subagents' reports, to avoid races.
- Do NOT re-run the full-repo scan after your deletions; trust the initial
  scan and leave transitive-cascade cleanup for the next sweep.
- Run `fvm flutter analyze --no-pub --no-fatal-infos` after your edits; if it
  flags unused imports from your deletions, remove them and re-run.

Report back (under 200 words): files deleted (count + paths), symbols
removed (qualified names), allowlist entries you think are still needed
(with why), anything that needed judgment.
```

## Step 3: Coalesce results

From the orchestrator session, once all subagents report:

1. Manually apply the allowlist additions/removals subagents flagged to
   `tool/find_unused_allowlist.json` and `tool/find_unused_allowlist.md` in
   one edit (avoids concurrent-write races).
2. Run:

```bash
make format-check
fvm flutter analyze --no-pub --no-fatal-infos
fvm flutter test
make find-unused-ci
```

If `find-unused-ci` still finds something, that's a cross-area cascade
(deleting something in `lib/core` exposed dead code in a feature). Decide
whether to spawn a second round for the affected areas or accept it as the
next sweep's problem.

## Step 4: Summary report

Aggregate the per-area reports into one summary: grand totals (files
deleted, symbols removed, allowlist entries changed) plus a one-liner per
area. Surface any subagent that flagged "judgment needed".

# Caveats

- **Generated files are roots and are never touched.** `find_unused_code.dart`
  already excludes `.g.dart`, `.freezed.dart`, `.gr.dart`, and anything with
  a "GENERATED CODE" header. Never hand-edit or delete these; they
  regenerate from `dart run tool/generate_analytics_schema.dart` or
  `build_runner`, per the area's codegen.
- **Conservative bias.** The scanner has simple regex-based symbol
  extraction and no cross-file transitivity; it can both under- and
  over-report. When in doubt, allowlist instead of delete, and say so in
  the report.
- **`make find-unused-ci` is the CI gate**, not `--no-allowlist`. Its
  purpose is to keep the allowlist accurate, not to force zero findings.
- **Don't bundle this with unrelated changes.** Dead-code removal touches
  many files; bundling refactors makes review harder. One PR per cleanup
  pass.
