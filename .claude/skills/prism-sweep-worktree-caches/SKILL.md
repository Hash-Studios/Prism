---
name: prism-sweep-worktree-caches
description: Reclaim disk space from Prism git worktrees by deleting regenerable build and dependency caches (Flutter build/, .dart_tool, ios/Pods, android/.gradle, functions/node_modules, web/node_modules, web/.next) while leaving the worktrees, branches, and all tracked files in place. Use this whenever the user mentions running low on disk, "no space left on device", ENOSPC, a full disk, node_modules eating space, worktrees taking up space, cleaning or pruning worktrees, or asks how much space the worktrees are using, even if they only say "clean up my worktrees" or "why is my disk full" without naming caches. Prefer this over `git worktree remove` when the user wants space back but has not asked to lose the worktrees themselves.
---

# Sweep Prism worktree caches

Prism worktrees are cheap to make and expensive to keep. Each one that runs
`fvm flutter pub get`, builds the iOS/Android app, or installs the
Cloudflare Functions/Next.js dependencies materialises its own `build/`,
`.dart_tool/`, `ios/Pods`, `android/.gradle`, `functions/node_modules`, and
`web/node_modules`, routinely hundreds of MB to a few GB per worktree.
Prism's worktrees mostly live under `.claude/worktrees/*` of the main
checkout (`/Users/codenameakshay/Development/codenameakshay/Prism`), but
agents also create them elsewhere (scratchpad dirs, `~/.t3/worktrees/...`).
`git worktree list` from the main checkout is the source of truth for where
they all are. Don't assume `.claude/worktrees/` is the only place to look.

Removing a worktree reclaims the space but loses the branch checkout, any
`.env`, and uncommitted work. This skill takes the other half of the trade:
delete only what a build command can recreate, and leave the worktree
standing. The next build there refetches; nothing else changes.

## The one-liner

```bash
python3 .claude/skills/prism-sweep-worktree-caches/scripts/sweep_caches.py --repo /Users/codenameakshay/Development/codenameakshay/Prism
```

That reports and deletes nothing. Add `--apply` to delete.

## How to run it

Report first, then delete. The report is fast and it is the only chance to
notice something surprising before it is gone.

1. **Report.** Run the script with no `--apply`. Show the user the total,
   the worktree count, and the top few entries. Do not paste every row if
   there are many.
2. **Get a yes.** Deleting many GB is worth one confirmation even though
   everything is regenerable, because the cost lands later as slow rebuilds,
   not immediately.
3. **Apply.** Rerun with `--apply` and report what was actually freed.

If the user has already said "just clean it up", skip straight to `--apply`
and report. Insisting on a confirmation they already gave is friction, not
safety.

**When testing this skill or the script itself (not doing a real cleanup for
the user), only ever run it without `--apply`.** Never pass `--apply` to
prove the script works. The dry-run report is the proof, and running the
delete path in a session that is only being exercised for testing risks
destroying someone else's live build.

## Which worktrees get swept

By default: worktrees whose branch is **merged into `master`** or whose
**upstream is gone**. That work has shipped, so nobody is going to build
there again and the caches are pure cost.

Do not reach for an age filter as the primary rule. `git worktree add`
stamps every file with the creation time, so a worktree abandoned an hour
after it was made looks exactly as fresh as one being actively built in. On
a machine running many parallel agents, almost everything reads as zero
days old and an age gate silently protects nearly everything. `--days N`
exists, but only as an extra filter on top of `--all`.

| Flag | Effect |
| --- | --- |
| *(none)* | Branch merged into `master` or upstream gone. The safe default. |
| `--all` | Every worktree except the main checkout. Roughly double the space; any worktree an agent is mid-build in pays a refetch. |
| `--all --days 3` | `--all`, but skip anything whose files were touched in the last 3 days. |
| `--only PATH` | Just that one worktree, whatever its branch state. |
| `--include-main` | Also sweep the main checkout, which is otherwise always skipped. |
| `--json` | Machine-readable plan, for scripting or for asserting on before applying. |

A worktree with uncommitted changes is still swept. The sweep only removes
gitignored caches, so dirty source is never at risk, and skipping dirty
trees would forfeit a lot of reclaimable space for no real protection.

## Why the delete list is safe

Three independent gates have to agree before anything is removed:

1. **A fixed allowlist** in the script names the cache paths and the
   command that restores each one. An allowlist fails closed: a new
   heavyweight directory is ignored until someone adds it deliberately,
   which is the property you want in a tool whose whole job is deleting
   things.
2. **git must call the path ignored** in that specific worktree
   (`git check-ignore`). This is the gate that does the real work, because
   `.gitignore` can differ between worktrees on older branches.
3. **git must have zero tracked files under that path** (`git ls-files`).
   This one exists specifically because of a real gap in this repo:
   `functions/.gitignore` lists `lib/**/*.js` and `lib/**/*.js.map`, but
   the compiled `functions/lib/*.js` files are actually committed:
   `check-ignore` alone would call them disposable and delete tracked
   code. The script only sweeps `functions/lib/__tests__` (genuinely
   untracked compiled test output), never `functions/lib` as a whole, and
   the tracked-file gate double-checks this for every target so a future
   allowlist addition can't repeat the mistake.

If a target passes gate 1 and 2 but fails gate 3, the script leaves it in
place and reports it under "tracked but allowlisted" so the gap is visible
rather than papered over.

On top of that it never follows a symlink out of the worktree, and never
touches `.env`, `.doppler.yaml`, `key.properties`, `key.jks`,
`google-services.json`, `GoogleService-Info.plist`, `AuthKey.p8`,
`sentry.properties`, or `lib/firebase_options.dart` even if a glob somehow
reaches them. Those matter more than their size suggests: Doppler is
project-scoped and a worktree's `.env`/secrets are hand-copied from the main
checkout, which costs real human time to restore. `lib/firebase_options.dart`
is a gitignored stub (see `AGENTS.md`) that analysis, tests, and debug
builds depend on; it isn't a cache and regenerating it for real needs
`flutterfire configure` against a live Firebase project, not just a rebuild.

## Restoring a swept worktree

Nothing needs restoring until someone actually works there again. When they
do:

```bash
fvm flutter pub get
cd functions && npm ci    # if that worktree touches Cloud Functions
cd web && npm ci          # if that worktree touches the Next.js site
```

`npm ci` is the installer for both `functions/` and `web/`. Flutter
`build/`, `ios/Pods`, and the gradle caches rebuild on the next
`fvm flutter build`/`pod install`/Gradle invocation with no separate step.

## Reading the report

The per-worktree lines are sorted biggest first and tagged with why the
worktree was selected (`[merged]`, `[upstream gone]`, `[--all]`). Footers
worth reading out:

- **"Left alone: N worktree(s) on branches still in flight"**: the
  default's protection working. Mention `--all` if the user needs more
  space than the default found.
- **"Allowlisted but not gitignored"**: a `.gitignore` gap. Worth
  surfacing once; the fix is a rule in the repo, not a change to this
  skill.
- **"Allowlisted and gitignored, but git already tracks committed files
  under them"**: the tracked-file gate caught something. This should
  normally be empty; if it isn't, don't loosen the gate, investigate why
  tracked files ended up under a cache path.

## When not to use this

If the user wants the worktrees *gone* (stale branches, a tidy
`git worktree list`), that's `git worktree remove`, not this. This skill
deliberately keeps every worktree. Use it when the complaint is about disk
space, not about clutter.
