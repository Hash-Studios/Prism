# X posting

Backend only. Three scheduled functions post wallpapers to the @PrismWallpapers account on X. The owner approves some posts in a private Telegram chat. The code is in `functions/src/social/`.

## Slots

| Slot | IST | Pipeline | What it posts |
|---|---|---|---|
| `am` | 09:30 | `grid` | 3 phone walls from the Wallhaven toplist (SFW and sketchy, never NSFW) |
| `noon` | 13:00 | `panorama` | A Studio desktop companion (2560 x 1600) cut into 3 tall panels |
| `eve` | 17:00 | `still` | One Studio wall, After Dark first |
| `night` | 20:00 | `still` | One Studio wall. Sunday: today's Wall of the Day and a question |

Each post lands at its slot time plus or minus up to 15 minutes, uniformly at random, so posting times change every day. Posts carry no link and no link reply: X bills a post with a URL at about $0.20 against about $0.015 for a plain post. Links live in the account bio and a pinned post.

## Jobs

| Function | When | Does |
|---|---|---|
| `socialPrepare` | 07:00 and 10:00 IST | Builds today's missing posts into `socialPosts/{day}_{slot}`, stores the images in R2 (`social/<postId>/<sha256>.jpg`, private bucket), sends previews to Telegram |
| `socialPublish` | Every 5 minutes (so the jitter is not rounded to quarter hours) | Posts what is due, reconciles unknown results |
| `socialTelegramWebhook` | On each button press | Applies the press at once, shows a toast, and replaces the buttons with the outcome |
| `socialMeasure` | 06:30 IST | Reads X metrics for posts and replies at 24 hours and 7 days into `metrics` |

## Post states

`pending_approval` → `approved` → `posting` → `posted`. Other ends: `skipped` (owner skip, no content, or 2 hours late), `failed` (X refused), `dry_run`, `uncertain`.

Automatic retries never intentionally resend a possibly accepted create. X provides no exactly-once guarantee. Owner-requested retries can duplicate a post if the owner misses it on the account.

- The publisher claims a post with an `attemptId` in a transaction. Dispatch is fenced by that attempt. Accepted posts and their cooldown records commit atomically. Rate limits clear dispatch state before retry.
- A network error or 5xx on the create call can mean X made the post. The doc stays `posting`. After 10 minutes the next run reads the account's own posts and matches the text, exact uploaded media IDs, image count, and dispatch time. Timeline reads paginate. Link replies require matching text, parent, and dispatch time. With no match after 30 minutes, the doc becomes `uncertain` and the owner gets **Post again** and **Leave it** buttons.
- A 429 puts the post back to `approved`.
- One new main post per run, so a late run never sends a burst. Replies and reconciliation still run. Unfinished queue entries are scanned regardless of day.
- Uncertain buttons bind to the attempt and distinguish main posts from replies. Old approval buttons cannot resolve uncertainty. Failed uncertain alerts retry on later passes.

A post with a non-empty `replyText` also gets a reply, with the same rules on `replyStatus`. The pipelines set it empty, so no reply is sent.

## Approval

| Pipeline | Approval |
|---|---|
| `grid` | Always |
| `panorama` | Until `autoApprove.panorama` is `true` |
| `still` | Not needed unless `autoApprove.still` is `false` |

An approval binds to `contentHash` (image hashes, text, link reply, alt text, and sensitive flags). The publisher recomputes it and requires a matching owner approval for every grid. Only presses from the owner in the owner's chat count. Telegram calls `socialTelegramWebhook` with a secret header derived from the bot token; any other request gets 403. `socialPrepare` registers the webhook on every run. Failed approval previews retry during publish passes until delivered or expired. No decision by 2 hours after the jittered `scheduledAt`: skipped.

The webhook accepts only POST requests and compares the secret in constant time. An empty bot token fails closed. Authenticated updates return 200 even if processing fails, so Telegram does not repeat a failed press. The owner can press an unresolved button again. Telegram feedback calls each time out after 5 seconds, within the function's 30-second limit. Registration failures do not stop preparation.

## Grid checks

- Wallhaven `purity=110` (SFW and sketchy, never NSFW), `categories=111`, toplist 3 days then 1 week, portrait, at least 1080 x 1920. Search and detail responses must have matching SFW or sketchy purity.
- Four searches (two pages per range) and at most 30 details use at most 34 API requests per grid run. This is below Wallhaven's 45/minute limit for one run, not a shared limit across overlapping runs.
- At most `sketchyPerPost` sketchy walls (default 2).
- Youth-coded tags reject, including teenage, schoolboy, student, minor, and young-child variants. `blockedTags` and `blockedIds` reject. Grid source tags are retained so current blocklists can be checked again before posting.
- Vision SafeSearch: `adult` VERY_LIKELY rejects. `violence` or `medical` LIKELY or higher rejects. Any UNKNOWN or missing rating rejects.
- No image is flagged by default, because X hides a flagged post ("Content warning: Nudity") and its reach drops to almost zero. `adult` POSSIBLE or LIKELY, or `racy` VERY_LIKELY, is only a suggestion: the preview shows "Vision suggests a flag on: N of 3". **Approve** posts with no flag. **Approve + flag** flags the suggested images, or all images when Vision suggested none. The flag changes `contentHash`, and the approval binds to the new hash. If X's metadata call fails for any flagged image, the entire post stops before publication.
- Cooldowns: Wallhaven walls 180 days, Prism walls 60 days (`socialSeen`).
- Takedown: delete the post on X and add the Wallhaven id to `blockedIds`.

## Setup

1. Secrets (Secret Manager): `X_API_KEY`, `X_API_SECRET`, `X_ACCESS_TOKEN`, `X_ACCESS_SECRET` (OAuth 1.0a user tokens for @PrismWallpapers, Read and Write), `SOCIAL_TELEGRAM_BOT_TOKEN` (a new bot, not the channel bot), `SOCIAL_TELEGRAM_OWNER_CHAT_ID` (the owner's private chat with that bot). All six must exist before deploy, even in dry run.
2. Deploy `socialPrepare`, `socialPublish`, `socialMeasure`, `socialTelegramWebhook`. Then force-run `socialPrepare` once, so it registers the Telegram webhook.
3. Create `socialConfig/current`:

   ```json
   {"enabled": true, "dryRun": true, "slots": {"am": true, "noon": true, "eve": true, "night": true},
    "sketchyPerPost": 2, "autoApprove": {"panorama": false, "still": true}, "blockedTags": [], "blockedIds": []}
   ```

4. Dry run. Every post previews in Telegram and ends as `dry_run`. Nothing goes to X. Each `socialPrepare` run rebuilds today's never-attempted posts with new walls and sends new previews. Deletion rechecks the state in a transaction, so a concurrent publisher claim protects the post. Attempted posts stay intact, including uncertain posts after an owner drop or retry. A live run never replaces an existing post.
5. Set `dryRun` to `false`.

Kill switch: `enabled: false`.

Metrics missing on one side retry independently without replacing an existing sample. Late samples record their actual collection time. Dry run does not send link replies, even for previously posted main posts. Disabled slots and current ID/tag blocklists are checked before new posts. Invalid still auto-approval values require approval.

## Before going live (phase 0)

- Post a test panorama from a test account. Check that X shows the 3 panels in order after a tap, on iOS and Android.
- Check the `sensitive_media_warning` payload of `POST /2/media/metadata` on a test image. `x.ts` sends `{adult_content: true}`.
- Check the pay-per-use price: about $0.015 a post (no URLs, so about $2 a month at 4 posts a day).
- Calibrate `FLAT_PANEL_STDEV` in `content.ts` on real After Dark companions.

## Not built yet

Lock screen setup (P3), creator spotlight (P4), video (P6), weekly report. See the plan in `docs/growth/x-posting-plan.md` (local only).

## Review follow-ups

- Sunday night is built by the 10:00 IST run, after Wall of the Day is picked at 09:00 IST.
- An owner **Post again** gives the post a fresh posting window, so the old slot's 2-hour expiry does not skip it.
- The sensitive metadata payload remains a launch blocker until phase 0 validates that X applies the warning. Offline tests prove fail-closed handling of metadata errors, not that X honors the payload.
