# Intake (Step 1)

Gather the bug report before creating a worktree or writing code. A sharp repro is what keeps
you from cutting a worktree against the wrong root cause. This file owns the intake checklist,
the slug rules, and a worked example. Worktree mechanics live in `worktree-and-pr.md`; CI/merge
mechanics live in `ci-and-merge.md`; Prism-specific traps live in `prism-gotchas.md`: this file
does not restate them.

## What to collect

| Field | Required | Notes |
| --- | --- | --- |
| **Logs** | Strongly preferred | A Sentry event, a Cloud Functions log line (`firebase functions:log` or the Firebase console), or a Flutter console stack trace. This is usually the fastest path to a `file:line`. |
| **What went wrong** | Required | One or two sentences in the reporter's words. |
| **Screenshots** | Optional but valuable | The reporter may paste images or give file paths. **Read them.** A wallpaper app bug is often visible: wrong crop, missing thumbnail, broken feed layout. |
| **Expected vs. actual** | Required | "Expected the wallpaper to apply; actual: app shows a generic error toast." Pins what "fixed" means. |
| **Repro** | Preferred | Steps, or the exact screen/action that triggers it. |
| **Affected area (guess)** | Helpful | `lib/` (Flutter app), `functions/` (Cloud Functions), or `web/` (marketing site). A guess only; confirm during diagnosis. |

A permission-denied toast does not by itself pin the affected area: it could be a genuine rule
gap in `firestore.rules`, or a client calling the wrong collection/sourceTag. A Cloud Function
error does not by itself mean the *deployed* function is broken either; it may already be fixed
in `functions/src` but not yet deployed. Reconcile the reported symptom against what the log
actually shows before deciding where the fix lives.

If a required field is missing and the bug is ambiguous, **ask once**, then proceed. Don't stall
a fixable bug waiting for logs you can infer from a clear screenshot and description.

## Slug rules

Derive a short, stable kebab slug from the bug summary. It names both the worktree
(`.claude/worktrees/<slug>`) and the branch (`bugfix/<slug>`), so it must be a safe git ref:

- Lowercase, `[a-z0-9-]` only. Spaces and punctuation become single hyphens.
- No leading, trailing, or doubled hyphens.
- Short and descriptive: 2-4 words. Prefer the symptom or the subsystem.
- Examples: `feed-permission-denied`, `wallpaper-apply-crash`, `coins-refund-mismatch`.

## Confirmation template

Fill this in from what the reporter gave you and **echo it back before creating the worktree**,
so a wrong assumption is caught before any branch exists:

```
Bug:        <one-line summary>
Slug:       <kebab-slug>            -> worktree .claude/worktrees/<slug>, branch bugfix/<slug>
Symptom:    <what the user sees / screenshot summary>
Expected:   <what should happen>
Actual:     <what happens instead>
Repro:      <steps or the triggering action>
Signal:     <key log line / exception + the file:line it points at, if known>
Area guess: <lib/ | functions/ | web/>   (confirm in diagnosis)
```

## Worked example

```
Bug:        Applying a wallpaper from the Prism feed silently fails on some devices
Slug:       feed-apply-permission-denied
            -> .claude/worktrees/feed-apply-permission-denied, branch bugfix/feed-apply-permission-denied
Symptom:    User taps "Set wallpaper", nothing happens, no error shown
Expected:   Wallpaper applies and a success toast shows
Actual:     Firestore write for the view-count increment silently fails
Repro:      Open a wall not owned by the current user, tap set wallpaper, watch debug console
Signal:     [Firestore] permission-denied on transaction: collection: walls, sourceTag: wallpaper.apply.view_increment
            (lib/core/firestore/firestore_tracked_client.dart)
Area guess: lib/ or firestore.rules (the client writes to a field the rules don't allow for a non-owner)
```

Takeaways this example teaches:

- The log line's `sourceTag` pinpointed the exact call site, so diagnosis started at
  `wallpaper.apply.view_increment`, not a guess.
- The reported symptom ("silently fails") and the logged `permission-denied` needed to be
  reconciled with `firestore.rules` before deciding whether the fix was a rule change or a
  client change writing a field it shouldn't.
- The fix should be reproduced by a failing test (a rules emulator test or a repository unit
  test with a fake) before any change, so the eventual merge is safe.
