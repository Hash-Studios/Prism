# Weekly challenges

Day 19, ROADMAP G4. This is the pre-code contract and verification plan. The draft PR targets `master` and must contain the state table and UTC timeline before code starts. Do not merge the PR as part of this task.

The user chose to wait for all pending entry reviews after voting closes. The server then picks the winner and reserves the following UTC calendar day. Admission through the existing wall create trigger remains under parent design review. No feature code starts until that review is recorded.

## Theme and entry contract

The server reads the ordered `challengeThemes` queue first. A planned seed script supplies six themes. Theme text remains subject to review. The proposed command is `cd functions && node lib/scripts/seedChallengeThemes.js --dry-run`. This script does not exist yet. The command is planned and was not run. Never run a real seed during this implementation task.

If the queue has no theme, use the top visible, open wall request created during the prior UTC week. Sort by votes descending, `createdAt` ascending, then document ID ascending. For a November 2 opening, the request window is October 26 00:00 through November 2 00:00 UTC, with the end excluded. Do not reuse the requests page's 30-day window or its bounded Top scan. If neither source supplies a theme, skip the week. Do not open an empty challenge.

The user chooses **Upload** or **Create with AI**. AI starts with the theme as a seed. It does not generate or spend coins without the user's action. Normal upload, moderation, and AI payment rules apply.

The existing wall create path carries optional `challengeId`. The server retains the link only for the creator's own new wall submitted during `[opensAt, closesAt)`. Trusted snapshot `createTime`, not a client date or trigger delivery time, defines submission time. An edit cannot attach a prior wall. Each user has at most three admitted entries over the challenge's lifetime. Withdrawn and rejected entries still use their places.

### Admission review remains open

The requested design uses the existing create path and server stripping, like `remixOf`. It does not add a submission callable or client-write admission slots. The proposed rules change allows an optional, immutable `challengeId`. Challenge public data has read-only client access. Private admission and vote records remain protected.

The parent is reviewing whether a create-trigger transaction can enforce admission safely. The review must prove trusted ownership, snapshot `createTime`, atomic count changes, and stripping of the fourth link. It must cover delayed events, retries, concurrent submissions, delete-and-recreate, and changed wall identity. An unverified wall link must never create a public entry, receive votes, or enter winner selection. This design is not settled.

## State table

All transitions are server-owned. A retry must converge to the same result.

| State | Entry admission | Votes | Transition |
|---|---|---|---|
| `scheduled` | Closed | Closed | At Monday 00:00 UTC, open if a theme exists. |
| `open` | Own new walls only, maximum three per user | Signed-in users can vote on approved entries | At the next Monday 00:00 UTC, close admission and voting. |
| `voting_closed` | Closed | Closed | Wait for all pending admitted reviews. Late approvals join the result set. Finalize after all reviews settle. |
| `winner_picked` | Closed | Closed | Store the winner and reserve the following UTC date. Recheck validity before WOTD use. |
| `archived` | Closed | Closed | Keep the final history after the award date is resolved, including a no-winner outcome. |

No pending review timeout is specified. A review backlog can delay the award. An empty eligible result produces no reservation and uses normal WOTD. The archive record must state that no eligible winner existed.

## UTC timeline

| UTC time | Result |
|---|---|
| November 2, 2026, 00:00 | Open the example challenge and close the previous week's voting. |
| November 9, 2026, 00:00 | Close example entries and voting. Freeze vote input. Wait for pending reviews. Open the next challenge if it has a theme. |
| November 9, after all reviews settle | If every review settles Monday, pick the winner and reserve November 10. |
| November 10, 2026, 03:30 | Use the valid November 10 reservation for WOTD. Otherwise use normal WOTD. |
| November 11, 2026, after the last review settles | In the delayed-review example, a Wednesday approval can qualify. Pick the winner Wednesday and reserve November 12. |
| November 12, 2026, 03:30 | Use the valid November 12 reservation in the delayed-review example. |

These are two possible review completion times, not two policies. A Wednesday approval cannot win an award finalized Monday. Under the chosen policy, a review still pending Wednesday prevents Monday finalization. Late approvals count, but no vote can be added after Monday 00:00 UTC.

## Votes, order, and WOTD

Only approved entries are visible in the public challenge list. Pending or rejected content remains private under existing moderation rules. A later approval keeps the original admission and records its first approval server timestamp once. Withdrawal removes public visibility and winner eligibility. Reapproval does not reset the first approval timestamp or restore an admission place.

Voting requires sign-in. One deterministic UID vote document represents one user's vote on one entry. Self-votes and votes across a block in either direction fail. The server owns vote documents and counts. Use the requests limit of 200 vote changes per user per UTC day, including its retry and no-op behavior. Do not infer an account-age requirement from requests without a separate decision.

Top sorts by votes descending, first approval timestamp ascending, then entry ID ascending. New sorts by first approval timestamp descending, then entry ID ascending. Winner selection follows Top order and takes the first candidate that passes both `isWotdEligible` and `readyWall`. A high vote count alone does not qualify a wall.

The server reserves a UTC date, not a rolling 24-hour delay. It rechecks the wall incarnation, approval, withdrawal, eligibility, and delivery before use. If the winner was withdrawn, try the next valid candidate from the settled ranking for that date. If no valid reservation remains, use normal WOTD. Retries must not overwrite another date reservation or publish two WOTD picks.

## Proposed server data

Collection names below, except `challengeThemes`, are proposed until the admission review finishes.

| Record | Required data and access |
|---|---|
| `challengeThemes/{themeId}` | Ordered server theme queue. Client writes denied. |
| `weeklyChallenges/{challengeId}` | Theme source and snapshot, UTC bounds, state, result, and finalization time. Public projection only. |
| Challenge entry | Wall document ID, logical wall ID, snapshot `createTime` with full timestamp precision, owner UID, first approval server timestamp, vote count, and moderation or withdrawal state. Server writes only. |
| Entry vote at `{uid}` | Deterministic voter UID identity. Server transaction updates the vote and count together. No public voter list. |
| Per-user admission record | Challenge ID, owner UID, lifetime admitted count, and stable admission identities. Server writes only. Deletion does not reset the count. |
| Date-keyed WOTD reservation | UTC `YYYY-MM-DD` key, challenge ID, entry ID, wall identity and incarnation, and use state. Server writes only. |
| Notification record | Stable challenge, event, and recipient key, with separate inbox and push attempt state. Server writes only. |

Never trust client-sent owners, counts, approval times, state, or winner data. Keep public projections separate from private user records. Compare the current wall incarnation before each effect. A reused document ID must not inherit an old entry, vote count, or reservation.

## Inbox and push

Challenge notices include an inbox item and a preference-aware push. Reuse the existing notification catalog, preference keys, and route mapper. Each event and recipient has a stable key so retries do not create duplicate inbox items. Respect bilateral blocks when a notice concerns another creator. Deep links open the correct challenge and its current closed or archived state.

Firestore can atomically claim a notification effect. It cannot atomically commit with external FCM delivery. A crash after FCM accepts a push but before the server records success can cause a retry duplicate. A claim before send can instead lose delivery after a crash. Stable inbox keys and collapse keys do not guarantee exactly-once external delivery. Record this boundary in the implementation and PR.

## Current integration evidence

| Path | Current behavior or planned integration |
|---|---|
| `functions/src/onWallSubmitted.ts` | Existing `walls/{wallId}` create trigger validates and strips `remixOf`. Challenge admission is not implemented. |
| `functions/src/wallRemix.ts` | Existing ledger and wall incarnation checks provide a reference for retries. |
| `lib/data/upload/wallpaper/wallfirestore.dart` | Existing wall create payload carries `remixOf` and `requestId`. Proposed `challengeId` belongs in this path. |
| `functions/src/onWallApproved.ts` | Existing approval effects need challenge integration. |
| `functions/src/wallRequests.ts` | Existing request visibility and 200 daily vote-change limit. Theme fallback needs the exact prior-week query. |
| `functions/src/wallOfTheDay.ts` | `isWotdEligible`, private `readyWall`, and the 03:30 UTC scheduler. Reservation integration must retain the delivery check. |
| `functions/src/notificationHelper.ts`, `functions/src/notificationCatalog.ts` | Existing inbox, push, and copy contracts. |
| `firestore.rules`, `firestore.indexes.json` | Existing ownership, immutable remix link, and query rules. No challenge security is claimed. |
| `lib/features/wallpaper_upload/views/pages/upload_wall_screen.dart` | Upload entry point. |
| `lib/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart` | AI seed and generation route. |
| `lib/core/router/deep_link_parser.dart`, `lib/core/router/notification_route_mapper.dart` | External link and inbox navigation. |
| `lib/core/analytics/schema/analytics_events.yaml` | Typed analytics source, regenerated with `make analytics-gen`. |
| `tool/record_clip.sh` | Existing iOS and Android clip recorder. |

## Planned checkpoints and acceptance evidence

1. Record the state table and UTC timeline in the draft PR before code. Resolve the parent admission review. Keep one owner per changed file.
2. Implement backend transitions, admission, votes, moderation, notifications, and date reservations with focused tests. Review rules and indexes with the same contract.
3. Implement the layered client feature, screens, upload route, and AI route. Use `FirestoreClient` with a `sourceTag`. Widgets do not call repositories.
4. Add calm copy in all seven locales, `en`, `de`, `es`, `hi`, `id`, `pt`, and `pt_BR`. Follow `.impeccable.md`. Regenerate localization, analytics, and affected generated Dart files. Run `make file-gen` for affected generated sources.
5. Run the final Astra audit, fix accepted findings, then verify the exact current tree. The audit is planned, not complete.
6. Obtain local Firebase emulator and device proof. Publish approved QA screenshots on `qa/screenshots` and embed their raw URLs in the PR. Keep the PR against `master`, with no merge.

The required backend and rules cases include spoofed owner or time, old-wall attachment, fourth entry, concurrent admission, retry count drift, and changed incarnation. Cover exact UTC boundaries, scheduler retries, prior-week fallback ties, absent themes, late approval, pending reviews, and stable first approval. Cover self-votes, bilateral blocks, daily vote changes, withdrawal, rejection, deletion, and zero valid candidates. Cover WOTD eligibility, missing delivery, date conflicts, withdrawn winner fallback, and notification retry boundaries.

Required widget and BLoC cases include loading, empty, error, sign-in, Top, New, entry limit, closed state, delayed results, and archived results. Verify upload and AI seed propagation, link removal, stale challenge submission, moderation visibility, vote failure, block filtering, inbox, and deep links.

Completion requires `make ci`, the functions build and tests, `make rules-test`, and the required widget and BLoC cases. The functions command is `cd functions && npm ci && npm run build && node --test 'lib/__tests__/*.test.js'`. Device proof requires local emulator data on both iOS Simulator and Android emulator. Capture light and dark screens, upload and AI entry, inbox, deep links, week closure, delayed review settlement, and next-day WOTD. Record clips with `tool/record_clip.sh ios <out.mp4>` and `tool/record_clip.sh android <out.mp4>`. Review documentation against STE before handoff.

## Baseline and blockers

Baseline preparation installed dependencies. The functions build passed with 2,191 tests passed, 16 skipped, and zero failed. Logs are at `/tmp/prism-challenge-baseline`. These are baseline results, not feature proof. Neither tracked lockfile changed. `make ci` stopped at 313 pre-existing info-level findings before the full Flutter tests. No feature tests or device runs are claimed.

`docs/DAILY_SHIPS_PLAN.md` is absent. Use `.impeccable.md` and the user's calm-copy requirement. Mobbin fetch is unavailable. This Linux host has no `xcrun` or `axe`, so iOS proof needs a suitable host. Current local Firebase wiring is missing. External AI and GitHub upload need explicit local-only adapters for local proof. A stale emulator lock names another worktree and an absent process. Confirm the owner has finished before takeover. These blockers do not count as passed checks.

## Planned release order

The release sequence is rules, indexes, functions, then the six-theme seed, all before the store build. Wait for indexes to become ready. Check compatibility with installed clients before rules deploy. Review the seed dry-run output before any real seed. Deploys, a real seed, and store uploads require explicit user authorization. The user has authorized QA screenshot publication for this PR. No deployment or real seed occurred.
