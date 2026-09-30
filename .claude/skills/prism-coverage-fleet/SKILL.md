---
name: prism-coverage-fleet
description: Drive one or more Prism app areas (lib/features/<name>, or a top-level lib/ folder like lib/core, lib/data, lib/auth) to a target line-coverage via a fleet of parallel per-area agents, each working in its own git worktree, then reconcile all their commits into ONE clean branch + PR against master on Hash-Studios/Prism with a per-area coverage delta table. Use when the user asks to "get lib/features/wallpaper_upload to 100% coverage", "raise coverage across the app", "coverage sweep", "bring core to full line coverage", or names several areas and a coverage goal. NOT for a single quick test (just write it), and not for fixing a bug that happens to lack a test (root-cause the bug directly).
---

# Prism Coverage Fleet

Fan out one agent per app area, each in an isolated git worktree, each driving its
area to the coverage target via TDD; then a coordinator phase folds every area's
branch into one clean integration branch, runs the full suite once, and opens a
single PR against `master` on `Hash-Studios/Prism`. The per-area isolation is what
makes the parallelism safe; the coordinator phase is what prevents the
duplicate-commit/rebase mess that ad-hoc parallel coverage runs produce.

## Coverage tooling check

Prism has no `lcov`/`genhtml` on this machine by default
(`which lcov genhtml`; confirm before relying on an HTML report). Coverage is
measured directly from `coverage/lcov.info` with `awk`, not `genhtml`; only
install/use `genhtml` if the user explicitly wants a browsable HTML report.

```bash
fvm flutter test --coverage --no-pub
awk -F'[,:]' '/^DA:/ {t++; if ($3>0) h++} END {printf "%.1f%% (%d/%d)\n", 100*h/t, h, t}' coverage/lcov.info
```

Generated files are excluded from the denominator: filter `SF:` records
matching `.g.dart`, `.freezed.dart`, `.gr.dart` out of `lcov.info` before
computing the percentage, and say so in the delta table footnote. The
per-area Python snippet in Phase 1 already does this filtering; use it (with
`AREA = 'lib'`) for a whole-app number too.

## Inputs

- **Areas**: an explicit list (`lib/features/wallpaper_upload lib/features/wall_of_the_day`),
  `all` (every `lib/features/<name>` directory plus one area for the remaining
  top-level `lib/` folders (`lib/core`, `lib/data`, `lib/auth`, `lib/analytics`,
  `lib/theme`, `lib/notifications`, `lib/global`, `lib/logger`); read `ls
  lib/features` and `ls lib`, don't hardcode the list), or a single
  `lib/features/<name>` / `lib/<top-level>` path. Tests for an area live under the
  mirrored path in `test/` (e.g. `lib/features/wallpaper_upload` → `test/features/wallpaper_upload`,
  `lib/core/coins` → `test/core/coins`).
- **Target**: line-coverage percent, default **100**. Anything below target that
  the agent can prove genuinely untestable (platform-channel glue, `Platform.isIOS`
  branches, main.dart bootstrap) is handled by `// coverage:ignore-line` /
  `// coverage:ignore-start`/`-end` comments **only with justification recorded in
  the PR body**, never silently.

Prism is a single app (`pubspec.yaml` has no `workspace:` list, unlike a
multi-package monorepo) plus a vendored `packages/cloud_functions` plugin. Never
target that package; it's third-party code, not app code to cover.

## Phase 1: Baseline (coordinator, no fleet yet)

For each area, measure current line coverage from the repo checkout:

```bash
fvm flutter test --coverage --no-pub test/<mirrored-area-path>
# Line coverage from lcov, generated files excluded, for just this area's SF: records:
python3 - <<'PY'
import re
AREA = 'lib/features/wallpaper_upload'  # ← edit this; must match SF: paths' prefix
hit = total = 0
skip = False
with open('coverage/lcov.info') as f:
    for line in f:
        if line.startswith('SF:'):
            path = line[3:].strip()
            skip = not path.startswith(AREA) or path.endswith(('.g.dart', '.freezed.dart', '.gr.dart'))
        elif line.startswith('DA:') and not skip:
            total += 1
            if int(line.split(',')[1]) > 0:
                hit += 1
print(f'{AREA}: {100*hit/total:.1f}% ({hit}/{total})' if total else f'{AREA}: no coverage records')
PY
```

Record `<area> -> baseline%`. Areas already at target are reported and skipped,
don't spawn agents for them. If an area's tests are *red* at baseline, stop and
report it; the fleet raises coverage on green code, it doesn't repair broken
suites.

## Phase 2: The fleet (one agent per area, parallel, cap 3)

For each remaining area, create a worktree and spawn an agent:

```bash
git fetch origin master
git worktree add .claude/worktrees/coverage-<area-slug> -b coverage/<area-slug> origin/master
```

Use a filesystem-safe slug for `<area-slug>` (e.g. `lib/features/wallpaper_upload` →
`features-wallpaper_upload`, `lib/core/coins` → `core-coins`).

Cap at **3 concurrent** agents (each runs its own Flutter toolchain via `fvm`;
more thrashes the machine). Each agent's brief (via the `Agent` tool,
`subagent_type=fast-worker`):

1. Work ONLY inside `.claude/worktrees/coverage-<area-slug>`, touching ONLY
   `test/<mirrored-area-path>/**` (new/extended tests). Product code changes
   under `lib/` are out of scope. If covering a line would require changing
   product code, note it in the report instead of doing it.
2. Run `fvm flutter pub get` once in the worktree.
3. Loop: measure (`fvm flutter test --coverage --no-pub` + the awk/python
   snippet above, scoped to this area's `SF:` records) → find the largest
   uncovered region in `coverage/lcov.info` → write focused widget/unit tests
   for it, mirroring the patterns already used in sibling files under
   `test/<mirrored-area-path>/` → re-measure.
4. If a test exposes a real product bug, do NOT fix it. Record it (file:line,
   symptom) in the report; the coordinator surfaces it for a separate fix.
5. Gates before committing: area's tests green
   (`fvm flutter test --no-pub test/<mirrored-area-path>`),
   `fvm flutter analyze --no-pub --no-fatal-infos` clean, and
   `fvm dart format --line-length 120` on only the files it wrote (never
   repo-wide (`make format-check` uses `lib test` as its scope, so a stray
   reformat elsewhere shows up as noise in the diff).
6. Commit with explicit paths only
   (`git add test/<mirrored-area-path>/...`), message
   `test(<area-slug>): raise line coverage <baseline>% -> <final>%`, push
   `coverage/<area-slug>`. Do NOT open a PR; the coordinator owns the PR.
7. Report back: final %, tests added, uncovered-but-untestable lines (with
   why), bugs found.

## Phase 3: Reconcile (coordinator)

Area branches touch disjoint paths (`test/<mirrored-area-path>/`), so folding
is conflict-free by construction:

```bash
git fetch origin
git worktree add .claude/worktrees/coverage-fleet -b test/coverage-fleet origin/master
cd .claude/worktrees/coverage-fleet
# for each area branch:
git cherry-pick $(git rev-list --reverse origin/master..coverage/<area-slug>)
```

One commit per area survives, linear, no merge knots. Then the full-suite check:

```bash
make format-check
fvm flutter analyze --no-pub --no-fatal-infos
fvm flutter test
```

Then one PR against `master` on `Hash-Studios/Prism`:

- Title: `test: coverage fleet, <n> areas to <target>%`
- Body: the **delta table** (`area | baseline | final | tests added`), the
  justified exclusions, and any product bugs the fleet uncovered (as a
  checklist for follow-up fixes).
- Open with `gh pr create --base master ...`; merge per repo policy (check
  `CONTRIBUTING.md` / branch protection before assuming squash vs. merge,
  don't default to force-merging).

## Phase 4: Cleanup

After the PR merges: remove all `coverage-*` worktrees
(`git worktree remove .claude/worktrees/coverage-<area-slug>`) and delete the
per-area `coverage/<area-slug>` branches (they're folded into the integration
branch, so `git branch -D` is safe once the PR is merged). Report leftovers
honestly if any worktree is dirty. Never force-remove.

## Summary format

```
Coverage fleet, <date>
area                        baseline   final   tests added
lib/features/wallpaper_upload            82.4%   100%    +37
lib/core/coins                 91.0%   100%    +22
...
Excluded (justified): <area> <file:lines> (<why>)
Bugs uncovered: <list or none> → flag for a separate fix
PR: #<n> (merged | open, CI running)
```

## Guardrails

- Fleet agents write **tests only**. A coverage run that "fixes" product code
  has scope-crept; product defects go in the report.
- Don't chase the last fraction of a percent with assertion-free "execution"
  tests. Every test must assert behavior. If the only way to cover a line is
  a meaningless test, that line belongs on the justified-exclusion list.
- Generated files (`*.freezed.dart`, `*.g.dart`, `*.gr.dart`) are excluded from
  the coverage denominator. Filter matching `SF:` records out of
  `lcov.info` before computing the percentage, and say so in the table
  footnote.
- One fleet at a time; re-running while `coverage-*` worktrees from a
  previous run exist means the previous run didn't finish. Reconcile or
  clean up first (the `prism-sweep-worktree-caches` skill can reclaim disk
  from finished ones, but won't remove the worktrees themselves).
