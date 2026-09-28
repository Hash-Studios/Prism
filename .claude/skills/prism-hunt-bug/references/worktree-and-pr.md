# Worktree and PR mechanics

Use the existing checkout if it owns the change and can preserve unrelated work. Otherwise
create a uniquely named worktree from `origin/master`, not whichever branch happens to be
current.

1. Inspect `git status --short --branch` and `git worktree list --porcelain` first. Other agents
   or sessions may already have worktrees open; do not touch their paths or branches.
2. Fetch `origin/master` before branching from it. Do not switch or reset an active user's
   checkout.
3. Use the native worktree tool, or `git worktree add -b bugfix/<slug> PATH origin/master`.
   Verify the new HEAD equals `origin/master` before editing.
4. Install dependencies only for the surface you're touching: `fvm flutter pub get` for the
   Flutter app, `npm ci` inside `functions/` for Cloud Functions, `npm ci` inside `web/` for the
   site. Each has its own lockfile; don't cross-link `node_modules` between `functions/` and
   `web/`.
5. Stub `lib/firebase_options.dart` in the new worktree before running any Flutter command (it
   is gitignored, so a fresh worktree never has it). See the main SKILL.md for the exact stub.

## Publishing when requested

Run Git with `-C PATH`; run `gh` with that checkout as its working directory. Inspect
`git diff --check` and the complete staged diff, including any regenerated
`functions/lib/**` or `lib/core/analytics/events/generated/analytics_events.g.dart`. Stage
explicit paths; never stage `lib/firebase_options.dart` or any local stub.

Write the PR body to a temporary file and use:

```sh
gh pr create --base master --head bugfix/<slug> --title "<title>" --body-file FILE
```

Describe the concrete symptom, cause, changed behavior, and verification (which gate you ran,
for which surface). Match the final diff and do not invent authorship trailers. Capture the
returned URL.

If the fix needs device proof, hand that to the `verify-prism` skill rather than improvising a
screenshot flow; if screenshots are wanted on the PR, they belong on the `qa/screenshots` orphan
branch, never mixed into the product diff.

A new PR or push does not authorize merge. Follow [CI and merge](ci-and-merge.md) for that
boundary.

## Cleanup only when requested

Do not sweep other worktrees as part of a bug fix; several may be active at once
(`.claude/worktrees/*`, `t3code-*`, scratchpad worktrees) and are not yours to remove. For a
requested cleanup, check tracked and untracked files and compare the local HEAD with the PR's
recorded head/merge evidence. A deleted remote ref is not evidence that all local commits were
pushed. Preserve anything uncertain; use non-force removal only for the authorized,
proven-safe worktree.
