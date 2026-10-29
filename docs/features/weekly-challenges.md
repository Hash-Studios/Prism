# Weekly challenges

Weekly challenges accept new wallpapers for one UTC week. Voting closes Monday at 00:00 UTC. The server waits for pending reviews, selects a winner, and reserves the next free UTC date for Wallpaper of the Day (WOTD).

## Themes and entries

The server consumes the ordered `challengeThemes` queue first. If the queue is empty, it selects the top visible, open wall request created during the prior UTC week. Ties use `createdAt` ascending, then document ID ascending. If neither source supplies a theme, the week is skipped. A skipped slot cannot reopen after themes change.

The seed contains six themes: Quiet horizons, Light through glass, Shapes in nature, After the rain, Small worlds, and Night colours. `functions/src/scripts/seedChallengeThemes.ts` creates missing theme records without overwriting existing records.

The feed card opens the challenge detail page. **Upload** carries the challenge seed through image selection and the upload draft. **Create with AI** supplies the theme without starting generation or spending coins. Normal upload quotas, moderation, and AI payment rules apply. Challenge context can be removed. Challenge AI submissions use a stable Firestore document ID for retries.

The wall create payload has an optional `challengeId`. Rules make that field immutable after creation. There is no submission callable or client-written admission slot.

`onChallengeWallSubmitted` is a separate authenticated create trigger in `functions/src/weeklyChallenges.ts`. The existing `onWallSubmitted` trigger retains its original event type and submission effects. The new trigger avoids an event-type replacement migration and isolates challenge admission retries.

Admission requires the original creator and a trusted snapshot `createTime` within `[opensAt, closesAt)`. Each user has three lifetime places per challenge. Rejection and withdrawal do not refund places. Invalid links, including a fourth entry, are removed asynchronously.

Admission decisions bind the wall document ID and full creation timestamp. A transaction records the decision and lifetime count together. Retries do not consume another place. An old, changed, or recreated wall cannot inherit admission. Approval delivered before admission is reconciled.

Only `unknown` and `api_key` event labels can reach Auth UID resolution. Admission requires the exact enabled Auth UID and an email match with the original submission. Missing provenance, explicit system principals, and failed ownership checks cannot admit. There is no email-lookup or emulator identity fallback.

## State table

All transitions are server-owned.

| State | Entry admission | Votes | Transition |
|---|---|---|---|
| `scheduled` | In-window creates can be admitted before the open-state update. | Closed | The Monday 00:00 UTC slot opens the week if a theme exists. |
| `open` | Own new walls, up to three lifetime places. | Approved entries only. | The next Monday 00:00 UTC closes entries and voting. |
| `voting_closed` | Only delayed decisions for pre-close creates can complete. | Closed | Wait for admission decisions and pending reviews, then finalize. |
| `winner_picked` | Sealed. | Closed | Reserve the next free UTC date and recheck the winner before publication. |
| `archived` | Sealed. | Closed | Retain the award outcome, including no winner or a missed reservation. |

`scheduleWeeklyChallenges` runs every 15 minutes. Only the intended Monday 00:00 UTC schedule slot opens a week. Other ticks reconcile existing challenges. Scheduler delivery can be late. A Monday retry older than its week cannot open that week.

The close barrier scans linked pre-close wall incarnations, admission decisions, and entries in a consistent read-only transaction. It waits for missing create-event decisions and pending reviews. Finalization rechecks the revision and wall/account guards before sealing. There is no review timeout. A backlog can delay the award indefinitely.

## UTC timeline

The examples assume no reservation collision.

| UTC time | Result |
|---|---|
| November 2, 2026, 00:00 | Open the example week if a theme exists. Close the prior week's voting. |
| November 9, 2026, 00:00 | Close example entries and voting. Wait for pending reviews. The next week can open independently. |
| November 9, after all reviews settle | Select the winner and reserve November 10. |
| November 10, 2026, 03:30 | Publish the valid reserved winner as WOTD. |
| November 11, after all reviews settle | Alternative delayed-review case: select the winner Wednesday and reserve November 12. |
| November 12, 2026, 03:30 | Publish the delayed-review winner. |

A review still pending Wednesday prevents Monday finalization. A late approval can qualify, but no votes can be added after Monday 00:00 UTC. A reservation collision moves the award to the next free UTC day.

## Votes and awards

Voting requires sign-in. The server rejects self-votes and bilateral blocks. Deterministic UID vote documents allow one vote per user per entry. The daily limit is 200 vote changes per user per UTC day. The transaction samples time on each retry, so retries cannot cross the close or midnight boundary with stale time.

Top sorts by votes descending, first approval timestamp ascending, then entry ID ascending. New sorts by first approval timestamp descending, then entry ID ascending. Reapproval does not reset first approval. Winner selection follows Top order and requires both `isWotdEligible` and `readyWall`.

Settlement freezes the candidate ranking. Live displayed counts can decrease after account deletion without changing that ranking or the original selection. Before publication, WOTD rechecks admission, incarnation, approval, withdrawal, account state, and delivery. An unavailable winner falls back through the frozen ranking. Exhausted candidates produce no winner and normal WOTD selection proceeds.

The WOTD pointer and reservation consumption commit together. An unavailable published award is checked on the 15-minute schedule and can be replaced from the settled ranking. Recovery is intended within 15 minutes, subject to scheduler and delivery delays. A healthy or newer pointer cannot be overwritten by a stale replacement attempt.

The `challenge_winner` badge is implemented with zero coin and XP rewards. Replacement award winners also receive the badge. Winner notices use stable inbox IDs and preference-aware private pushes. Inbox copy is localized in seven locales. Native winner pushes use English fallback for installed clients without the new resource keys. A crash after FCM accepts a push can still cause duplicate delivery.

## Privacy, navigation, and analytics

Entry, vote, member, and admission records are not publicly readable. `listWeeklyChallenges`, `getWeeklyChallenge`, and `setChallengeVote` provide the client API. Public callable views filter approval, deleted creators, changed incarnations, and bilateral blocks. The client repeats visibility checks when it hydrates wallpapers. Only the caller receives `myAdmittedWallIds`, including their pending, rejected, and withdrawn admissions.

Entry requests scan at most 200 ordered rows per page. Challenge lists return at most 20 records per page. Optional cursors continue both queries. The client follows empty filtered pages and deduplicates entries. It collects all pages before presenting the complete list. Live pagination is not an immutable snapshot. Settlement scans remain complete. Large-cohort workload performance is unverified.

`https://prismwalls.com/challenges/<id>` opens challenge detail. Winner notifications also carry `route: challenge` and `challenge_id`. Detail refreshes after wallpaper navigation and app resume. Vote failures roll back optimistic state and reload when the entry, session, or voting window is no longer valid.

`challenge_entered` requires fresh server admission confirmation, not the initial wall save. Durable entry intent supports delayed confirmation. `challenge_shared` requires an actual successful native share result. Copy, save, dismissal, and unsupported share results do not emit completion. Global WOTD topic pushes retain their existing delivery behavior and cannot filter each viewer's blocks.

## Release requirements

The deployment order is rules, indexes, functions, then the reviewed seed, all before a store build. Indexes must be ready before functions and the client use the new queries. Functions include the new `onChallengeWallSubmitted`, `onChallengeWallWritten` moderation reconciliation, challenge callables, `scheduleWeeklyChallenges`, existing approval integrations, and WOTD exports. `onWallSubmitted` does not require an event-type replacement migration. Deploy both new challenge triggers before enabling submissions. Historical creates do not replay when a trigger is added. Check live deployment state separately if an intermediate trigger version was deployed.

Deploy the web challenge routes, Worker, and link association files before sharing challenge links. Source contract checks do not prove live association or native link delivery.

The safe seed preview command, already executed, is:

```sh
cd functions
node lib/scripts/seedChallengeThemes.js --dry-run
```

After explicit deployment and seed authorization, the reviewed seed command is:

```sh
cd functions
node lib/scripts/seedChallengeThemes.js --apply
```

No deployment or real seed has occurred. Deploys, seed application, and store uploads require explicit final authorization. QA screenshot publication on `qa/screenshots` is already authorized.

## Evidence and open gates

PR #759 contains the state table and UTC timeline from before implementation. The feature and security review is in `001903fd4`, the additive trigger and link review in `58b4d6758`, and local QA plus warm-navigation fixes in `bf1740e2b`. Later test-only commits classify QA configuration and register empty challenge fixtures in existing Home tests. See [the decision record](weekly-challenges-decisions.tsv).

The pushed `35deb06de` passed pre-push checks, including 2,244 Functions tests with 23 skips and rules smoke tests. Later scoped QA review passed 129 Flutter tests, three enabled-QA transport tests, and 12 Node tests. Home fixture review passed 140 tests with seven existing render skips. These results do not establish full current-head CI.

The full run at `/tmp/prism-challenge-final-ci-2.log` was interrupted after missing Home fixture registrations caused failures. Its zero shell exit is invalid evidence. The registrations are fixed. A fresh full run is in `/tmp/prism-challenge-final-ci-3.log`; no result is claimed yet.

Corrected Android evidence uses the app built at `bf1740e2b`. Later commits change tests only. The corrected run shows Home, the challenge page, votes, both warm navigation directions, loaded upload and AI composers, winners, and inbox in light and dark. WOTD is visible in light. Earlier mistimed screenshots are excluded. The [published evidence index](https://raw.githubusercontent.com/Hash-Studios/Prism/8769d3f7ccc6688b0830d1bfe77b7e9b23f962d0/qa-2026-10-30/weekly-challenges/corrected-20261029T203433Z-401811/evidence-index.json) records hashes and capture scope. Screenshots and the continuous clip are embedded in [PR #759](https://github.com/Hash-Studios/Prism/pull/759).

The continuous clip shows a vote, local closure, and a visible reserved WOTD. Publication selected the historical fixture `qa-wall-3`, not the newly closed winner `qa-wall-0`. It does not prove that this newly selected winner became WOTD. Local backend assertions test finalization and reservation publication separately. Fixtures use administrative entries and readiness overrides. iOS proof is unavailable on this Linux host.

The authenticated Firestore admission probe received `fake-auth-id@gmail.com` from the emulator. Admission rejected it, removed `challengeId`, and created no entry. No identity was remapped. Production CloudEvent UID mapping and successful authenticated upload admission remain unproven.

Composer evidence does not prove upload-byte transport, AI generation, R2 delivery, native purchases or push delivery, or production scheduling. Native share completion and measured native zero-egress remain unproven. Hosted checks, merge, deployment, store release, and live behavior are separate gates. Nothing has been deployed or seeded in production.
