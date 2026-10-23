# Telegram release announcement

Use this for a public app release only. The Studio automation in
`functions/src/studio/telegram.ts` posts a daily approved wall, with its own Firestore day claim.
Do not call that trigger, reuse its claim record, or describe it as a release posting tool.

## Draft and review

Draft from the release diff and confirmed store listings. State only features in the shipped
build, platforms where that version is publicly available, and verified store links. Get links
from `lib/core/constants/app_constants.dart`, then open each link and confirm the listing and
version. In particular, do not copy the outdated iOS link from `web/lib/site-config.ts` without
verification.

Reuse feature screenshots captured during the `verify-prism` release smoke test. Check the
original PNGs at full size for account details, notifications, device identifiers, or other
private data. Prefer the original image. If Telegram needs a JPG or a crop, create a separate
publish copy and preserve the verification evidence. Keep a manifest with version/build, commit
SHA, platform, feature, original path, and publish-copy path when applicable. Do not post if no
relevant, reviewed screenshot is available; this blocks only the announcement, not the store
workflow.

Show the human the exact final text, destination channel, ordered images, store links, and
screenshot manifest. Ask for feedback on the draft first. Before sending, obtain explicit approval
of that exact copy, image set/order, and channel. Approval of a draft or of a release step alone
does not authorize posting. If the human already approved the exact same final package, do not ask
again. A change to copy, images, or destination needs new approval.

Use the following copy style, approved by the user. Lead with the version and a concrete benefit,
then short user-facing bullets, verified availability and links, and an invitation for feedback.
This example uses the v3.9.0 changelog. Rewrite its facts for each release; copy feedback does not
authorize a live post.

```text
Prism 3.9.0

This update fixes a few things that got in the way of finding and saving your next wallpaper.

• Unlocked Weekly Drops open and save again.
• Explore creators' wallpapers and see your full Following and Followers lists.
• On Android, the Wall of the Day widget updates daily again.

Plus fixes for profiles, notifications and account security.

[Confirmed availability and store links]

Have feedback? Tell us what needs attention next.
```

Pair this example with existing QA screenshots of Weekly Drops, a creator profile, and the Android
widget, if available and suitable. This image plan is review context, not part of the caption.

## Send after approval

Wait until the release is publicly available in at least one store. TestFlight and an uploaded
build are not public availability. Confirm availability and the version in each listed store;
omit a platform that is not public yet. Use `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` from
Doppler `prd`. Keep the values in process memory or a protected secret input. Never print them,
put them in command arguments, or include them in logs. Do not invent a local CLI; this repository
has no release announcement command.

Keep the caption in `caption.txt`, screenshot manifest in `images.json`, and posting receipt in
`receipt.json` under `.claude/skills/verify-prism/artifacts/releases/<VERSION>+<N>/telegram/`.
Save publish copies there too. This directory is gitignored. Preserve it across release sessions
and pass its path to the next agent. If the record is unavailable on another machine, inspect the
channel and reconcile prior delivery before sending.

Before sending, check the release's saved Telegram receipt. If it is already `posted`, do not send
again. If it is `pending` or `uncertain`, inspect the channel and reconcile with the human before
any new send. Save a `pending` receipt with the approved text, destination, ordered image paths,
and approval before making the request. Afterward, update it to `posted` with every returned
`message_id`, or `uncertain` if delivery cannot be determined. Keep this receipt with the release
record so a rerun cannot silently duplicate the announcement.

Construct a direct HTTPS request to the Telegram Bot API in-process, using the existing secret
values without logging the request URL or body. Use multipart form data:

- For one image, call `sendPhoto` with multipart fields `chat_id`, `photo` (the image file), and
  `caption`. Use plain text with no `parse_mode`; keep the caption at or below 1024 characters.
  Telegram photo uploads must be at most 10 MB, have width plus height no greater than 10,000,
  and have an aspect ratio no greater than 20. Make a publish copy if an image needs resizing.
- For 2 to 10 images, call one `sendMediaGroup`. Apply the same photo limits to every image.
  Select no more than 10 relevant images; do not split them into multiple albums. Set `chat_id`
  to the destination and `media` to JSON describing the ordered photos. Put the caption on the
  first photo only, keep it within 1024 characters, and
  use matching `attach://<name>` values for each multipart image part. The media group must have
  2 to 10 items. Keep the caption plain text with no `parse_mode`, at or below 1024 characters.

If the public release uses a staged rollout, say "rolling out" and do not imply that all users can
update now. Do not state a platform as available until its public listing has the release.

Do not use `sendMessage` followed by photos: that can leave a partial announcement. Before
sending, validate all image files, order, caption length, approval record, and receipt state. Make
one request.
Require both a successful HTTP response and Telegram JSON with `ok: true`. Save every returned
`message_id` with the release version, destination, response time, and image-to-message mapping.
Do not log the bot token, full request URL, multipart body, or private image data. If the request
times out or the response is malformed or missing, the result may be ambiguous. Do not retry
blindly, because Telegram may already have posted it. Check the channel and report the ambiguity
to the human before any further send.
