# Coins and downloads

Saving a wallpaper costs coins. A user without coins can watch a rewarded ad. This page covers the price on the Save pill, the saved state, ads, ad privacy, and what the app does when a payment or a reward does not finish.

## What it does

- The Save pill shows the price.
- The app never charges for a save that does not finish. It refunds the coins.
- The app never loses a reward for an ad the user watched. It adds the coins later.
- The user can reopen the ad consent choices (EEA and UK).

## Where to find it

- The Save pill and the download button: `lib/features/ads/views/widgets/download_button.dart`. The wallpaper detail screen uses it.
- The low-balance sheet: `lib/features/ads/views/widgets/coin_gate_sheet.dart`, opened by `lib/features/ads/biz/coin_gate.dart`.
- Ad privacy: `AdConsent.instance.privacyOptionsRequired()` and `AdConsent.instance.showPrivacyOptions()` in `lib/features/ads/data/ad_consent.dart`. Settings calls them.

## Platforms and plans

| User | What the Save pill reads | What happens on tap |
|---|---|---|
| Signed in, free | `Save · 5` (`Save · 15` for a Pro wallpaper) | Spends the coins, then downloads. No sheet when the balance covers the price. |
| Pro | `Free with Pro` | Downloads. No charge. |
| Guest, free wallpaper | `Save` | Offers a rewarded ad, or Buy Pro. |
| Guest, Pro wallpaper | `Save` | Offers Sign in or Get Pro. It never offers an ad. |
| Any user, wallpaper already in Downloads | `Saved` | Opens the "Already in Downloads" sheet. |

The semantic label of the pill includes the price, for example "Save. Costs 5 coins".

## How it works

### Price and saved state

- The price comes from `CoinSpendAction.cost()`: 5 coins, or 15 for a Pro wallpaper.
- The pill reads `Saved` when the Downloads index holds the link (`DownloadedWallIndex.has`).
- When the user taps a `Saved` pill, the app checks the native Downloads list. If the file is still there, a sheet shows "Already in Downloads" with two buttons: "Open" and "Download again (-5 coins)". Pro users see "Download again" with no price. A second download always costs the full price. There is no free re-download.
- If the file is gone from the list, the app skips the sheet and saves as normal.

### Low balance and ads

- The sheet shows only when the balance is below the price. Its title is "Not enough coins". It says how many coins are missing.
- "Watch ad (+10)" shows the ads left today when the server has told the app, for example "Watch ad (+10) · 3 left today".
- If one ad does not cover the price (a Pro wallpaper with 0 coins), the sheet comes back after the ad with the coins still missing.
- When the user refused ad consent, the sheet has no ad button. It says "Ads are off. Change this in Settings > Privacy."
- When the daily limit is reached, the sheet has no ad button. It says "Daily limit reached. Back tomorrow."
- When no ad plays, the toast gives the reason: consent refused, no ad available, or offline.
- The third watched ad opens the Pro paywall. The paywall opens at most once in 24 hours (settings key `paywall_ad_watch_prompted_at`). A Pro user resets the counter.

### Paywall errors

When the paywall cannot open (no RevenueCat paywall, no offering, or an SDK error), the app shows "Plans are not available right now. Check your connection and try again."

### Pending refunds and rewards

The app keeps a queue in settings (key `pendingAiRefunds`, kept for old builds). Each entry is a refund or a reward.

| Entry | Added when | Retried with |
|---|---|---|
| Refund | A spend got no answer after two tries (downloads and AI), or a refund call failed. | `awardCoins` refund with the debit `transactionId`. |
| Reward | A rewarded ad award got no answer after two tries. | `awardCoins` with the same `requestId`. The server never pays twice. |

The app retries the queue at app start, when the app resumes, when the network returns, and every 30 seconds while the queue has entries. A refund entry lives 10 minutes (the server window). A reward entry lives 24 hours.

### Downloads that do not finish

- Before each paid save, the app adds an entry to a list in settings (key `pendingDownloads_v2`). An entry holds the transaction id, the user id, the link, the action, the time, and a `saved` flag. Each paid save has its own entry, so two saves never share one.
- Every change to an entry names its transaction id. No change looks for an entry by link or by the signed-in account. A retry of the same wallpaper, a second button on the same wallpaper, or a sign-out during the save never touches the entry of another payment. An unknown transaction id changes nothing.
- The spend returns the transaction id as `CoinMutationResult.pendingDownloadTxId`. The coin gate passes it to the button through `CoinGateSpec.onPaid` right after the charge, before it checks that the screen is still there.
- When the native save or enqueue reports success, the button sets `saved` on its own entry. The button marks an entry only when its own tap paid.
- The coin gate settles the entry on every way out of a paid tap:

| How the tap ends | What the gate does |
|---|---|
| The save worked | Removes the entry. |
| The save failed and the refund is confirmed | Removes the entry. |
| The save failed and the refund is not confirmed (offline, refused, signed out) | Releases the entry. |
| The save failed and the action has no refund | Releases the entry. |
| The user left the screen before the spend reply, and the refund is confirmed | Removes the entry. |
| The user left the screen before the spend reply, and the refund is not confirmed | Releases the entry. |

- Recovery refunds an entry that is not `saved` and is older than 2 minutes. It uses the transaction id of that entry. It removes a `saved` entry without a refund. It serves only the entries of the signed-in account. An entry of another account stays until that account signs in.
- While a save runs in the app, recovery skips its entry, however old it is. A slow save, for example a Photos permission dialog left open, is never refunded while it runs. The app keeps this list of running saves in memory only. An entry leaves the list only after the new state (`saved`, or removed) is stored. If that write fails, the app logs the error and keeps the entry protected until the app restarts.
- A released entry is not running any more. Recovery then refunds it at once if it is older than 2 minutes, or when it turns 2 minutes old. The stored entry does not change on release.
- After a restart nothing runs, so recovery treats every stored entry as in the rules above.
- Recovery runs at app start, when the app resumes, when the network returns, and on a timer. A younger entry gets a timer that fires when it turns 2 minutes old. A refund that failed for a network reason keeps its entry, and the 30 second retry loop tries again. A refund the server refuses for good removes the entry.
- An entry with no valid time counts as old. The time is not valid when it is missing, not a number, or not finite (for example `1e309`). A time far ahead of the clock counts as old too. One bad entry never stops the other entries from loading.
- Older builds kept one entry in the key `pendingDownloadMarker`. The app moves it into the list on the first read and deletes the old key. The old marker had no `saved` flag, so the app flags the moved entry `legacy`. Recovery checks only a `legacy` entry against the Downloads index: when the index holds the link, it removes the entry with no refund. Otherwise it refunds the entry. An entry written by this build never reads the index.

### Ledger label

A paid save sends `label`: the wallpaper title, or "Wallpaper by <creator>". The server keeps 60 characters. The coin history shows it.

### Ad privacy

- Google UMP asks for consent at the first ad load.
- `privacyOptionsRequired()` is true when the user may reopen the choices. `showPrivacyOptions()` opens the UMP form. Both never throw.

### Analytics

| Event | Fields |
|---|---|
| `ad_load_result` | `result`, `reason` |
| `ad_show_result` | `result`, `reason` |
| `ad_consent_result` | `status` (`can_request` or `refused`) |
| `download_attempt` | `source`, `premium` |
| `download_result` | `result`, `reason`, `stage` |
| `coin_low_balance_nudge_shown` | Unchanged. It fires when the low-balance sheet shows. |

`download_result.stage` is `gate`, `spend`, or `download`.

Fix: the `subscription_conversion` event now fires only from the paywall result. A premium status found at start or on reinstall no longer logs it.

## Limits

- The Downloads index only knows downloads made after the index existed. Only an entry moved in from an old build is checked against it.
- The app cannot tell if a download that the system finishes later is complete. An entry that is not `saved` and is older than 2 minutes counts as unfinished, unless its tap still runs in the same app session.
- The refund window on the server is 10 minutes for downloads. An entry found after that is cleared without a refund.
- The coin balance chip still has fixed red and green colours.

## How to test

1. Sign in as a free user with 20 coins. Open a wallpaper. The pill reads `Save · 5`. Tap it. The balance drops by 5 and no sheet shows.
2. Set the balance to 2. Tap the pill. The sheet says 3 coins are missing. Tap "Watch ad (+10)". After the ad, the download starts.
3. Open a Pro wallpaper with 0 coins. Watch one ad. The sheet comes back and says 5 coins are missing.
4. Tap the pill of a saved wallpaper. The sheet "Already in Downloads" shows. "Open" opens Downloads. "Download again (-5 coins)" charges 5.
5. Use a Pro account. The pill reads `Free with Pro`.
6. Sign out. Open a Pro wallpaper. The sheet offers Sign in and Get Pro. It has no ad button.
7. Turn on airplane mode, start a save, and close the app at once. Open the app after 2 minutes online. The coins return with the toast.
8. In the EEA, refuse ad consent. The sheet hides the ad button and shows the Privacy message.
9. On iOS, reset the Photos permission and start a save. Leave the permission dialog open for 3 minutes. The coins stay spent and no refund toast shows. Allow access. The file saves.

Automated: `test/core/coins/coins_pending_test.dart`, `test/core/coins/coins_service_lifecycle_test.dart`, `test/features/ads/download_button_gate_test.dart`, `test/features/ads/biz/coin_gate_test.dart`, `test/core/purchases/paywall_orchestrator_test.dart`.
