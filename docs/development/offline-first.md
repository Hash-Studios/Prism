# Verify offline behavior

Prism's offline promise covers bundled content, saved metadata, and originals that are available on the device. It does not include the entire remote catalog.

An image preview is not proof that the original is saved. A wallpaper action must resolve a readable local original or explain that a connection is required. Temporary-cache cleanup must not delete retained originals, drafts, or account-owned changes waiting to sync.

## Stored content and limits

| Content | Retention |
| --- | --- |
| Feed metadata | Up to 100 snapshots, 512 KiB per snapshot, and 4 MiB total. Refresh expiry does not remove the offline fallback. |
| Wallpaper catalog | Up to 500 public metadata records and 2 MiB. Local search covers these known records only. |
| Retained originals | Up to 500 images and 512 MiB. A full store rejects another retained save instead of evicting saved images. |
| Upload drafts | Up to 15 MiB per file, 10 drafts and 60 MiB per owner, and 20 drafts and 150 MiB per device. |
| Notification inbox | The newest 500 entries within a 900 KiB encoded-record budget per owner. A single oversized item is skipped. |
| Temporary images and editor files | Disposable. Clearing temporary cache does not clear the stores above or pending account changes. |

The app checks retained files before use. A missing, empty, unsupported, or mismatched file is not available offline. Atomic record replacement covers process interruption, not power loss.

Paged feeds keep a bounded recent window. After enough deep scrolling, a cold offline start can show that saved window instead of the original first page. It does not preserve every page ever viewed.

## Guest entry and upgrades

Android now permits guest entry to the dashboard, as iOS already does. Account-only routes still require sign-in. A first offline installation uses two bundled wallpapers instead of requiring a remote feed.

Bundled wallpapers have no public server identity. Their detail share sends the local image. Link-only actions use the Prism app landing page, not a wallpaper link containing a device path.

The previous notification inbox was device-global and did not record an owner. The new inbox does not import those records into an account, because their owner cannot be established safely. The old cache is not deleted by this change. Server-backed notifications return after the account reconnects. New inbox records and read state are owner-scoped and durable.

A successful native photo save and a retained original are separate results. If local storage rejects retention or an acquisition record, the native save can still succeed. The app cannot waive a later charge without an exact owner-scoped acquisition record and verified original bytes.

Pre-upgrade download rows do not identify an owner. They can help identify an existing native download, but they do not grant a free repeat acquisition to the current account.

An acquisition made while premium remains eligible for a free repeat save after premium lapses, with the same owner, exact acquisition record, and verified local original.

## Premium while offline

Local features keep the signed-in account's last known paid capability while the device cannot refresh it. The app refreshes store state on reconnect. Offline access cannot detect a refund or revocation that the device has not received. This policy preserves the existing local capability behavior instead of introducing an arbitrary offline expiry window.

Retained image bytes do not grant premium. They also do not prove that another account acquired the wallpaper. New spends, rewards, purchases, restores, and other authoritative operations still require their existing server or store acknowledgement. Existing native wallpaper playlists can continue from prepared local files.

## Run the automated checks

Use the Flutter version pinned by FVM.

```sh
make ci CI=true FLUTTER='fvm flutter' DART='fvm dart' TEST_FLAGS='--concurrency=4'
```

`CI=true` uses the same non-fatal informational lint policy as hosted CI. Errors and warnings still fail. Without Firebase configuration, use the gitignored options stub provided by `tool/write_firebase_options_stub.sh`. Never commit the stub.

If native code changes, also run the native checks from the Makefile on a supported host. A Flutter test that reads a native source file does not establish that the native action works.

## Verify the app on both platforms

The PR owner supplies local and hosted check results. The reviewer supplies iOS and Android device results and before-and-after screenshots before merging. Keep the same theme, accent, screen size, content, and scroll position for each screenshot pair.

For each journey, prepare the content online, enable airplane mode, force-stop the app, and reopen it. Then reconnect and inspect the result. Check both light and dark themes where the journey has visible changes.

| Journey | Expected result |
| --- | --- |
| New installation without a connection | Guest entry reaches bundled content without a sign-in requirement. |
| Returning launch | Saved content remains accessible without optional startup requests blocking it. |
| Home, categories, providers, collections, trending | Saved metadata remains visible after a cold restart and failed refresh. |
| Deeper feed pages | The retained recent window remains browsable without duplicates. Pages outside the documented cache limit are unavailable. |
| Search | Known wallpaper metadata is searchable. The app identifies local results instead of claiming a complete remote search. |
| Detail by source and ID | A failed or bounded-out remote lookup falls back to known metadata. A successful missing or moderated response does not revive an old record. |
| WOTD and archive | Saved picks remain browsable. The saved-today fallback requires a matching day. Firestore can still supply its last fetched pointer until a server refresh. With a warm cache and unchanged archive pointers, a server refresh must still resolve and prune a newly unavailable wall. |
| Set, crop, position, tint, edit, pair, share, and photo motion | A readable original works even when its HTTP freshness has expired. Existing platform restrictions remain in effect. |
| Download an acquired original | The app reuses verified local bytes without a new charge when the same owner has an exact source, ID, and URL acquisition record. Cache bytes alone do not qualify. |
| Save an original, then clear temporary cache | The saved original remains usable. |
| Delete a saved file outside Prism | Availability is repaired. The app does not claim that the deleted file is still available. |
| Favourites and blocks | Local intent survives a restart. Pending and rejected writes are not shown as server-confirmed. |
| Switch account A to B during a slow request | A's private records, notifications, and native favourite choices do not appear for B. |
| Upload draft | The upload entry offers the current owner's retained draft after restart without another gallery selection. The file and edited metadata survive. Publication still requires internet. |
| AI prompt and history | Saved prompt and history data remain usable. Generation and variation require internet. |
| Auto-rotate, Android tiles, and iOS Shortcuts | Prepared local content works without another transfer. Missing content has an honest fallback. |
| Coins, rewards, purchases, restore, deletion, and uploads | Cached display state never becomes a new server authorization. Failures do not imply a completed action. |

Also test an interrupted transfer, a corrupt record, low storage, a failed durable write, repeated taps, late rejection after a newer change, and Wi-Fi without internet. A retained save must not report offline availability before its durable file and record exist.

## Record the proof

Attach the device model, OS version, app build, journey, screenshot pair, and result to the PR. Include native action results, not only screenshots of the app. Mark untested journeys as untested.

Unit tests, a successful build, hosted CI, and device verification are separate gates. None substitutes for another.
