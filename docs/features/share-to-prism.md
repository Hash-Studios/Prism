# Share to Prism

From another app, the user shares one image or one link to Prism. Sending apps include Photos, Safari, Chrome, Instagram, Telegram and Files.

## Where to find it

- In the sending app, open the share sheet and choose Prism.
- Code: `lib/features/share_in/`.
- Native code: `android/app/src/main/kotlin/com/hash/prism/` and `ios/PrismShareExtension/`.
- Server: the `shareLinkImage` callable in `functions/src/shareLinkImage.ts`.

## Platforms

| Platform | How the share arrives | Guest mode |
|---|---|---|
| Android | `ShareTargetActivity` accepts `image/*` and `text/plain` | No |
| iOS (deployment target 15.0) | Share Extension `PrismShareExtension` | Yes |

## How it works

### Kinds of share

| Kind (`SharedItemKind`) | Input | What Prism does |
|---|---|---|
| `prismLink` | Short link `/l/CODE`, wall page `/wallpaper/ID` or `/share/ID`, public folder `/folder/ID` | Opens the page |
| `image` | One image | Shows a sheet with three actions |
| `url` | Any other web link | Looks for an image on the page |

### Prism link

- Wall page: Prism opens the page with the Save to Folder sheet already open (`WallpaperDetailScreen.openFolderSheet`).
- Folder page: Prism opens the page normally. A folder cannot go in a folder.
- Link that does not resolve: Prism opens the not-found page.

### Image

The sheet has three actions.

- **Set as wallpaper** opens the editor with crop (`WallpaperFilterRoute`). Then the normal Set flow runs. On iOS, Set saves the image to Photos. The editor hides Share for these images, including when the user has an account.
- **Make it fit** opens the photo job page from From your photo (`PhotoWallpaperPage(initialSource:)`). The row shows the coin cost from `photoJobCost`. When the photo already fits the screen, the row is disabled and says "Already fits your screen."
- **Upload to Prism** opens Edit wallpaper (`EditWallRoute`). Then the normal upload runs, with review.

### Any other link

Prism calls the `shareLinkImage` callable with the link.

- If the page has an og:image, og:image:secure_url or twitter:image, the app downloads that image. Then it shows the image sheet.
- If the page has none, the sheet says "Prism cannot use this link."

### Server: `shareLinkImage`

Input: `{url}`. Output: `{imageUrl}` or `{imageUrl: null, reason}`.

- Only https, port 443, and no user name or password.
- Every DNS answer must be a public address. Private, loopback, link-local, CGNAT, multicast, reserved, mapped and NAT64 addresses are blocked.
- The socket connects only to the address that was checked.
- Each redirect (at most 3) is checked again.
- A 5 s timeout covers the whole lookup.
- At most 512 KB of HTML is read.
- Malformed meta tags are scanned without repeated regex backtracking.
- The og:image URL must also be https and public.
- Guests may call it, because a guest sees the sheet before sign-in.
- Each caller address gets 30 lookups in a fixed 10-minute window, aligned to Unix time. Then the callable returns `{imageUrl: null, reason: "rate_limited"}`, and the app shows "Prism cannot use this link." A caller can make 30 lookups just before a boundary and 30 just after it. This is not a rolling-window limit.
- The address is the last `X-Forwarded-For` entry for direct gen2 callable ingress. Earlier entries can be client-supplied. This follows Google's [one-hop Cloud Run rate-limit example](https://github.com/GoogleCloudPlatform/nodejs-docs-samples/pull/3586), not an assumption that the first entry is trusted. The [Functions header reference](https://cloud.google.com/functions/docs/reference/headers#x-forwarded-for) describes a proxy chain, not a client identity guarantee for every ingress setup.
- Missing or malformed final entries fail closed with `{imageUrl: null, reason: "error"}`. The callable never falls back to an earlier entry, Express `ip`, or an "unknown" shared bucket. Equivalent IPv6 and IPv4-mapped spellings use one canonical address.
- Users behind the same NAT share a quota. Extra proxies, Hosting rewrites or load balancers can make the last entry a proxy address instead of the end user's address. Verify the header behavior on the actual gen2 endpoint before release and after any ingress change. Do not switch to the first entry to work around this.
- The counter is in `shareLinkQuota/<hash>_<window>`. The key uses a truncated SHA-256 hash. It is pseudonymous, not anonymous: an unsalted IPv4 hash can be recovered by enumeration, and the stable hash links windows. The document stores only `count` and `expireAt`, not a raw address, URL, image or account ID.
- `expireAt` is 20 minutes after the window starts. Firestore TTL deletion is asynchronous, [typically within 24 hours after expiry](https://firebase.google.com/docs/firestore/ttl). It is not a 20-minute deletion guarantee. The window in the document ID resets the quota without waiting for deletion.
- The Firestore transaction serializes increments for one address and retries conflicts. An outage or exhausted retries returns `{imageUrl: null, reason: "error"}` without DNS or HTTP work. Invalid URLs do not consume quota. Failure is closed, not an unmetered fallback.
- `maxInstances` is 10.

### Native handoff

Image:

```text
prism://share-in?id=<uuid>&src=<package>
```

Text or link:

```text
prism://share-in?text=<url-encoded text>&src=<package>
```

The text is at most 2048 characters.

- `src` is Android only. It holds the sending app's package from `Activity.referrer`.
- iOS text-share links have a UUID fragment, for example `prism://share-in?text=...#<uuid>`. It identifies one share delivery, not the shared text. Sharing the same text again creates a new UUID. The fragment is not part of the shared web URL.
- Only the `prism:` scheme carries a share. A web link to `/share-in` is not a share.
- Method channel `prism/shared_inbox`:
  - `take(id)` returns the file path. Errors: `invalid-id`, `missing`, `too-large`, `unreadable`.
  - `directory()` returns the inbox folder.
  - iOS only: `takePendingLink()` claims and removes the extension's pending link. It returns a share URL or null. Invalid payloads, links older than 5 minutes (a share whose open failed), and image IDs without a usable inbox file return null.
- Image limit: 50 MB.

### Android

- `ShareTargetActivity` has no UI and is translucent. It has ACTION_SEND filters for `image/*` and `text/plain`.
- It starts MainActivity with the `prism://share-in` link and FLAG_ACTIVITY_NEW_TASK.
- Reason: a share opens in the sender's task. MainActivity there would start a second Flutter engine.
- MainActivity gets the link like any deep link. A cold start uses the initial route. A warm start uses `onNewIntent`.
- The copy runs off the main thread into `filesDir/shared_inbox/<id>.<ext>`. It writes `<id>.part` first.
- Dart waits up to 30 s in `take`.
- A timeout cancels the copy, removes its partial file, and prevents a late provider result from publishing a file. Provider reads use at most four workers so one blocked provider does not hold up every later share.
- The VIEW intent forwards the content URI read grant to MainActivity before the share activity finishes.
- Prism refuses `file://` streams and content from its own providers. A share cannot point Prism at its private files.
- Code: `android/app/src/main/kotlin/com/hash/prism/SharedInbox.kt`, `ShareTargetActivity.kt`.

### iOS

- Target `PrismShareExtension`, bundle ID `com.hash.prism.ShareExtension`, App Group `group.com.hash.prism`, deployment target iOS 15.0.
- It accepts one image, one web URL or text.
- Its only UI is "Opening Prism".
- It copies the image file into the App Group folder `shared-inbox/<id>.<ext>` without decoding it. A large photo uses little extension memory.
- Image providers must supply a file representation. There is no `Data` or `UIImage` fallback. A copy checks the 50 MB limit while reading and publishes only a completed file.
- A provider that never replies closes the extension request after 30 s. Late copies are discarded.
- Before opening Prism, it atomically stores the link in the App Group's `shared-inbox/pending-link`. This is a single slot; a later share replaces a still-pending share. The system can drop the URL while Prism starts, so Prism also takes the pending link at startup and on resume. A received share URL also drains the slot.
- Taking the link first renames it to a unique claim file, then validates and removes it. Concurrent takes have one owner and cannot delete a newer stored link. An abandoned claim file expires with the normal inbox sweep.
- Prism uses one delivery tracker for both paths for the app's lifetime. Image IDs and iOS text-delivery UUIDs are claimed once, even if the second delivery arrives after navigation finishes or the share sheet closes. The dispatcher's pending/visible-text dedupe alone does not cover that case, especially for a Prism link that opens a wall or folder instead of the share sheet.
- Then the extension sends `openURL:options:completionHandler:` with the same link only to `UIApplication` in the responder chain. It skips `UIWindowScene`, which has the same selector but expects a different options type. The request completes on the main thread after the open callback or a 3 s fallback, whichever runs first. It completes immediately if there is no link or no application responder. Late callbacks cannot complete it again or keep the controller alive.
- Code: `ios/PrismShareExtension/ShareViewController.swift`, `ios/ShareInboxShared/ShareInbox.swift` (shared with Runner), `ios/Runner/PrismSharedInboxChannel.swift`.
- Target script: `ruby ios/scripts/add_share_extension_target.rb`. It is safe to run again.

### App

- `lib/features/share_in/domain/shared_item.dart`: `SharedItemKind`.
- `lib/features/share_in/data/shared_inbox.dart`: the shared inbox.
- `lib/features/share_in/data/share_link_image_repository.dart`: calls `shareLinkImage` and downloads the image.
- `lib/features/share_in/biz/share_in_resolver.dart`: resolves each share.
- `lib/features/share_in/views/pages/share_in_page.dart` and `views/widgets/share_in_sheet.dart`: the page and the sheet.

## Privacy

- Prism never sends a shared image anywhere unless the user picks Make it fit or Upload to Prism.
- For a web link, the server reads only the page HTML. It does not read or store the image or store the URL. It stores pseudonymous quota counters, with the retention and hash limitations above.
- The app downloads the image itself. Each redirect must remain https on port 443 without credentials. Each new connection resolves all addresses and refuses the host if any address is not public. The address exclusions match `functions/src/shareLinkImage.ts`, including mapped, NAT64, ISATAP, 6to4 and reserved IPv6 ranges. The socket connects to the checked address without another DNS lookup; TLS validates the original URL host. The client uses no proxy, and redirects use that same client.
- Downloads fail closed when an `HttpOverrides` network policy is installed. The downloader must not replace the local-QA fixture allowlist with public internet access. Local QA therefore cannot download these page images through the production downloader.
- The download is at most 25 MB, with one 20 s result deadline across redirects, headers, and body. Closing the client during DNS prevents a late answer from opening a socket.
- Known transport limitation: cancellation during a stalled TLS handshake can leave the connection open until the peer closes. In the pinned Dart SDK, `SecureSocket.secure` detaches the raw socket before it returns the secure socket; destroying the original socket or cancelling the completed TCP task does not close that in-progress handshake. The result deadline is not a socket-lifetime guarantee. The skipped `closing during stalled TLS closes the peer` regression records this unresolved case.
- Make it fit sends the photo to fal.ai and Google Cloud Vision. See [photo-wallpaper.md](photo-wallpaper.md).
- Make it fit checks the account again before preparing the upload, after preparation, and before a retry. Signing out or changing accounts prevents another send.

## Cleanup

- Native code puts an image in the inbox.
- When the user picks Set or Upload, the file moves to the hand-off folder `<temp>/share_in`. That flow owns the file.
- Set deletes its source when the editor closes. Upload keeps it through Edit and Upload, then deletes it when that flow closes.
- When the user closes the sheet, Prism deletes the file.
- If the account signs out or changes during the Set or Upload file hand-off, Prism cancels the action and deletes the moved file. It does not leave an auth-deferred route holding a deleted source. Fit also checks the account after closing the share page.
- Make it fit reads the file into memory and deletes it.
- At app start and at each share, `SharedInbox.sweep` deletes files older than 24 hours. It checks the inbox and the hand-off folder.
- Native sweeps also remove abandoned partial copies. If the OS stops the app and extension, cleanup runs on their next activation. Deletion at exactly 24 hours while both processes are stopped is not guaranteed.
- Duplicate delivery of an image id does not open a second owner of the same file. A new share replaces the previous share sheet and deletes its copy. A download that finishes after its sheet closes is deleted.

## Guests (iOS only)

- A guest sees the share sheet. Every action (Set as wallpaper, Make it fit, Upload to Prism) asks the guest to sign in first, the same as other wallpaper actions.
- The editor that Set opens has `WallpaperFilterScreen(sharedImage: true)`. It hides Share, so the shared image goes nowhere the user did not choose.
- Save to Folder on a wall link shows the sign-in prompt to a guest.
- Android has no guest mode.

## Analytics

| Event | Fields |
|---|---|
| `share_received` | `kind`, `source_app` (when the platform gives it) |
| `share_action` | `action` (`set`, `fit`, `upload`, `save` or `failed`), `kind` |

## Limits

- iOS gives no source app.
- One image for each share.
- A web page that hides its og:image behind JavaScript has no image for Prism.

## Release setup (iOS owner)

1. In the Apple Developer portal, register the App ID `com.hash.prism.ShareExtension`.
2. Enable the App Groups capability on that App ID. Select `group.com.hash.prism`.
3. Create App Store and development provisioning profiles for it. Or let Xcode automatic signing make them, with the same team as Runner.
4. Encode the App Store profile with base64. Save it as the GitHub secret `IOS_SHARE_EXTENSION_PROVISIONING_PROFILE_BASE64`. TestFlight stops with "no provisioning profile for PrismShareExtension" until this secret exists.
5. Archive the app. Check that `Prism.app/PlugIns/PrismShareExtension.appex` is in the archive.

## Release order

Do not deploy without the owner.

1. Deploy the TTL policy for the quota counters: `firebase deploy --only firestore:indexes`.
2. Deploy the callable: `firebase deploy --only functions:shareLinkImage`.
3. Release the app builds. A build without the callable shows "Prism cannot use this link." for web links. Images and Prism links still work.

No Worker change and no rules change are needed.

## How to test

1. `fvm flutter test test/features/share_in/ test/core/router/deep_link_share_in_test.dart`
2. `cd functions && npm run build && node --test 'lib/__tests__/shareLinkImage*.test.js'`
3. Android: `android/app/src/test/kotlin/com/hash/prism/SharedInboxLinksTest.kt`, and `verifySharedIntent` in `PrismNativeInstrumentation.kt`.
4. On macOS with Swift 6.2 or later: `swift test --package-path ios`. The `PrismShareInbox` target builds `ios/ShareInboxShared/ShareInbox.swift`, and the test target imports it to run `ios/RunnerTests/ShareInboxTests.swift`. This is native package proof, not an iOS app or extension build.
5. On a device, share a web page whose og:image is on a public CDN. Wait until the sheet shows the image preview and the Set, Fit and Upload rows. Only then is it proof of a successful pinned download. The sheet first shows a loading state and can then show an error, so an open sheet alone proves nothing. The unit tests prove the refusals without opening sockets.
6. Known failing transport regression: `fvm flutter test --no-pub --run-skipped --plain-name 'closing during stalled TLS closes the peer' test/features/share_in/data/share_link_image_repository_test.dart`.
7. On iOS, share an image and a Prism link with the app terminated, then with it already running. Close the resulting sheet or page, background and resume, and confirm it does not reopen. Share the same text again and confirm the new delivery opens. Also test a dropped system URL so only the pending-link path delivers it. Native package and Dart tests do not prove the extension-to-app OS handoff.
