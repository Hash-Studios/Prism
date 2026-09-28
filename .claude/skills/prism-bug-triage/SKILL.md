---
name: prism-bug-triage
description: Sweep ALL open bug signal for Prism (GitHub issues plus unresolved Sentry issues), dedupe and rank it, then fan out one parallel prism-hunt-bug run per confirmed bug and close the loop with each reporter. Use when the user says "triage the bugs", "clear the bug backlog", "go through open issues", "sweep Sentry and GitHub", "fix all the open bugs", "what's broken right now", or asks for a bug digest with fixes dispatched. This is the BATCH orchestrator; for ONE specific reported defect go straight to prism-hunt-bug (this skill's workers invoke it per bug). NOT for feature work, NOT for releases, NOT for App Store review triage.
---

# Prism bug triage

One command that turns "what's broken?" into a ranked backlog and a fleet of fixes. The skill
owns the *sweep, ranking, dispatch, and reporting*; every individual fix is delegated to
`prism-hunt-bug`, which already guarantees one-bug = one-worktree = one-branch = one-PR
isolation, so parallel hunts never collide.

Repo: `Hash-Studios/Prism`, default branch `master`.

## Preconditions

Stop and report, rather than running a half-blind sweep, if either check fails:

```sh
gh auth status
doppler secrets --project prism --config prd --only-names
```

The second call also confirms `SENTRY_ORG`, `SENTRY_PROJECT`, and `SENTRY_AUTH_TOKEN` exist as
secret names. Never print their values.

## Pipeline

### 1. Sweep: collect every open bug signal

Run both sources; neither alone is complete (users report what they see, Sentry reports what
crashes silently on a device you'll never hear from otherwise).

**GitHub issues:**

```sh
gh issue list --repo Hash-Studios/Prism --state open --label bug \
  --json number,title,body,author,createdAt,comments,labels --limit 100
# Also sweep unlabeled and mislabeled issues: many defect reports arrive without "bug",
# or under "missing" / "invalid" / no label at all:
gh issue list --repo Hash-Studios/Prism --state open \
  --json number,title,body,author,createdAt,labels --limit 100
```

Read every unlabeled/ambiguously-labeled issue's title and body and classify: defect (in scope)
vs. feature request / question (out of scope, e.g. labels `enhancement/new feature`,
`feature_request`, `question`, `v3`: leave untouched). When in doubt, treat as ambiguous
(step 4).

Roles for issues in flight are the canonical five defined in
`docs/agents/triage-labels.md` (`needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`). Check `gh label list --repo Hash-Studios/Prism` before applying
any of them: only `wontfix` is guaranteed to already exist as a repo label at any given time,
since the other four are provisioned separately. Create a missing label with
`gh label create <name> --repo Hash-Studios/Prism` only if the doc confirms it's one of the five
and it's still missing; otherwise fall back to a plain issue comment stating the role instead of
a label that doesn't exist yet.

**Sentry**: Prism's Sentry covers the Flutter app only (`sentry_flutter` in `pubspec.yaml`);
Cloud Functions (`functions/`) has no Sentry integration, so a Functions bug will only ever show
up via a GitHub report or `firebase functions:log`, never here. `sentry-cli` is the credentialed
path; org/project names are Doppler secret *names*, not hardcoded:

```sh
doppler run --project prism --config prd -- sh -c \
  'sentry-cli issues list --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" --query "is:unresolved" --max-rows 50'
```

Known limitation: `sentry-cli` gives issue titles, counts, and event tags
(`events list --show-tags`) but no stack frames. If a Sentry issue can't be diagnosed from its
title, tags, and code reading, mark it ambiguous rather than guessing.

### 2. Dedupe and cluster

Merge signals that are the same root cause: a GitHub issue describing a crash and a Sentry issue
recording it are ONE bug (keep both references: the GitHub reporter gets the confirmation ask,
the Sentry issue gets resolved). Cluster by feature area (feed, wallpaper apply, coins/premium,
notifications, onboarding, setups, web) so two hunts don't independently rediscover the same
underlying defect. Plain reasoning, no agents needed here.

### 3. Rank by impact

Order the deduped list:

1. **Crashes and data corruption**: app crashes, Firestore writes that corrupt user data.
2. **Wrong coins/premium/subscription state**: Prism has a real coins economy and paid premium
   tier (`functions/src/coinsCallables.ts`, `syncSubscription.ts`, `deleteAccount.ts`); a wrong
   balance or an entitlement that doesn't sync is near-crash severity, same as SplitFast treats
   a wrong money balance.
3. **Broken core flows**: feed loading, wallpaper apply/download, auth, notifications routing.
4. **Cosmetic / UI/UX**: visual glitches, the `UI/UX` label.

Within a tier, sort by Sentry event count / affected-user count, then recency.

### 4. Split: dispatchable vs. ambiguous

A bug is **dispatchable** when it has a nameable symptom and enough signal for
`prism-hunt-bug`'s intake (repro, a `sourceTag`/stack trace, or a clearly-pointable screen or
callable). Everything else: needs a product decision, can't be diagnosed without stack frames
Sentry's CLI can't fetch, might be intended behavior: goes on the **ambiguous list for the
user**. Never dispatch a guess. Tag ambiguous GitHub issues `needs-info` per
`docs/agents/triage-labels.md` when you need more from the reporter.

### 5. Dispatch the fleet

For each dispatchable bug, in ranked order, spawn a subagent (Agent tool, default type) whose
prompt is: *invoke the `prism-hunt-bug` skill for this ONE bug*, followed by the full intake
package (issue number and body, Sentry title/tags, expected vs. actual, repro, area guess from
step 2: `lib/` / `functions/` / `web/`). Launch independent hunts **in parallel, capped at 3
concurrent**: each hunt runs its own Flutter/npm toolchain in its own worktree, and more than
~3 thrashes a single machine. Start the next hunt as one finishes.

Tag each dispatched issue `ready-for-agent` per `docs/agents/triage-labels.md` (falling back to
a comment if the label doesn't exist yet: see step 1). Cap a single invocation at ~8 bugs; if
the ranked list is longer, dispatch the top 8 and put the remainder in the digest as "queued :
run triage again".

### 6. Close the loop per landed fix

When a hunt reports its PR merged:

- **GitHub-sourced bug**: comment on the issue, tagging the reporter:

  ```sh
  gh issue comment <N> --repo Hash-Studios/Prism --body "This should be fixed by #<PR> (<one-line what changed>). @<reporter> could you confirm this resolves it for you? It'll ship in the next release."
  ```

  Do **not** close the issue: the reporter's confirmation (or the next release) closes it. Only
  do this with explicit authorization: replying on or closing a real user's issue reaches them
  directly.
- **Sentry-sourced bug**: resolve it:

  ```sh
  doppler run --project prism --config prd -- sh -c \
    'sentry-cli issues resolve --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" <ISSUE_ID>'
  ```

If the fix was to `functions/src/*` and merged but not yet deployed
(`firebase deploy --only functions` not run), say so explicitly in the digest instead of treating
it as shipped: merging a Cloud Functions PR does not deploy it.

When a hunt escalates (CI red after its cap, needs a human decision), its worktree stays on disk
per `prism-hunt-bug`'s rules: carry that verbatim into the digest, don't retry it yourself.

### 7. Digest

End with one summary the user can read cold:

```
Prism bug triage: <date>
Swept: <G> GitHub issues, <S> Sentry issues -> <B> distinct bugs after dedupe

Fixed & merged:   #<issue> <title> -> PR #<pr> (reporter pinged / Sentry resolved)
Merged, not deployed: <title> -> PR #<pr> (functions/ change awaiting firebase deploy)
PR open (CI):     ...
Escalated:        <title> - <why>, worktree kept at <path>
Ambiguous (you):  <title> - <what decision/info is needed>
Queued:           <count> lower-ranked bugs - run prism-bug-triage again
```

## Guardrails

- **One triage invocation at a time.** Parallel hunts are fine (that's the design); parallel
  *triage sweeps* double-dispatch the same bugs.
- Feature requests, questions, and enhancement issues (`enhancement/new feature`,
  `feature_request`, `question`, `v3`) are untouchable: this skill fixes defects only.
- Never resolve a Sentry issue or ping a reporter for a fix that isn't actually merged.
- Never claim a Cloud Functions fix is live for users when only the PR is merged; deployment is
  a separate, authorization-gated step.
- The merge method is whatever `prism-hunt-bug` prescribes: don't override it from here.
- If `gh auth status` fails or Doppler is unreachable, stop and report which precondition broke
  instead of running a half-blind sweep.
