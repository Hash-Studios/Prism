# AI wallpapers (app)

The AI tab makes a wallpaper from a text description. Each image costs coins. This page covers the app side: the charge id, the error copy, "Try another", sign-in and the "Get coins" button.

## What it does

- The user writes a description, picks a style and a quality, and taps Generate.
- The app spends coins first, then asks the worker for the image.
- "Try another" makes a new image from the same prompt with a follow-up description.

## Where to find it

The AI tab. Code: `lib/features/ai_wallpaper/`. The worker side is in `docs/features/ai-charge.md`.

## Platforms and plans

| Platform | Free | Pro |
|---|---|---|
| Android and iOS | Pays coins for each image. The image has a Prism watermark. | Pays coins for each image. No watermark. |

## Result screen

The result fills the screen. The page opens on the prompt. It does not open on the last result.

### Opening and closing

- A successful generation or variation opens the result. The new wallpaper is the hero.
- A tap on a Recent wallpaper opens it full screen.
- "Edit prompt" returns to the prompt. Back does the same. The prompt text stays.
- Recent history stays below the prompt. Loading history does not open a result.

### Session strip

- The strip shows the wallpapers made on this page visit. The oldest comes first. The newest comes last.
- The strip shows when there are 2 or more wallpapers.
- A tap swaps the wallpaper. The swap does not generate or download anything.

### Actions

- Apply is the main action.
- On Android, Apply opens the Set screen with this wallpaper. The last target you picked is already selected.
- On Android, press Set to apply the wallpaper. Adjust is optional.
- The Set screen remembers the last target in `wallpaper.lastApplyTarget` for every entry point. This does not apply when a default target is saved.
- On iOS, Apply saves the wallpaper to Photos. Then the app shows the set guide.
- Save shows only on Android. On iOS, Apply already saves.
- Share, Submit and Try another stay on both platforms.

### Follow-up chips

- The result shows five chips: As watercolour, Night version, More minimal, Warmer and Add depth.
- The chips show only when `ai_variations_enabled` is true in Remote Config.
- The chips are off while a wallpaper is being made.
- A tap runs the variation path. The charge uses the price of the shown wallpaper's tier.
- The first tap asks first. The same sheet appears when the price goes up.
- The app stores the confirmed price in `ai.followUpConfirmedCost`.
- The sheet asks "Make a new take?" with "Make it" and "Cancel".
- The prompt sent to the worker is in English. Only the chip label is translated.

### Analytics

- `ai_result_applied` has `platform` and `from`. The `from` value is `hero` or `strip`.
- `ai_follow_up_used` has `chip_id`.
- `ai_strip_swapped` has `position` and `count`.

## How it works

### Charge id

1. `reserveForAiGeneration` spends the coins. It returns a `transactionId`.
2. `AiGenerationRepositoryImpl.generate` and `generateVariation` send that id as `chargeTxId` in the request body.
3. If the request times out (60 seconds), the app sends the same request once more with the same `chargeTxId`. The worker returns the stored image. The user is not charged twice and gets one image.
4. If a charge gives no id (a free path), the app sends no `chargeTxId` and does not retry.
5. A failed generation still refunds through `rollbackAiGenerationReservation`.

### Error copy

The app never shows the worker text. It maps the error code to this copy (`lib/features/ai_wallpaper/views/widgets/ai_error_copy.dart`):

| Code | Text |
|---|---|
| `rate_limited` | You reached today's AI limit. |
| `budget_exhausted` | AI is very busy right now. Try again later. Your coins were returned. |
| `unsafe_prompt` | That prompt is not allowed. |
| `unsafe_output` | The result was blocked. Try another prompt. |
| `charge_required`, `charge_invalid` | Payment check failed. Your coins will be returned. |
| `charge_in_progress` | Still working on your last image. |
| any other | Couldn't generate right now. Try again. |

When the text already speaks about coins, the app adds no second refund note. Other errors get " Coins refunded." or " Refund pending."

### Try another

The old button "Refine" suggested that the new image keeps the old one. It does not. The worker only adds your words to the prompt and uses a new seed. The button is now "Try another". It sits in the result actions. The sheet says that the result can look quite different. The event name `ai_variation_used` is the same.

### Sign-in

A signed-out user who taps Generate or Submit gets the sign-in sheet, not a toast. After sign-in the history loads.

### Get coins

When the balance is under the price, the button reads "Get coins · need N". It opens Rewards and scrolls to the "Earn coins" section (`RewardsRoute(scrollToEarn: true)`).

## Limits

- "Try another" does not use the image. A true image-based refine needs a worker change.
- A timeout retry helps only when the worker has the charge check (`ai-charge.md`). Before that, a retry can make a second image.
- `AI_REQUIRE_CHARGE` is off at first. Old app builds send no `chargeTxId` and still work until the owner turns the flag on.

## How to test

1. Run `fvm flutter test test/features/ai_wallpaper`.
2. The repository tests check the body, the retry and the error code. The page tests check the copy, the sign-in sheet and the charge id.
3. Manual: with a test account, generate an image. Then turn off the network in the middle of a request and check that the app shows the error and refunds the coins.
