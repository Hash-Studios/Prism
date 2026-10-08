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

The old button "Refine" suggested that the new image keeps the old one. It does not. The worker only adds your words to the prompt and uses a new seed. The button is now "Try another". The sheet says that the result can look quite different. The event name `ai_variation_used` is the same.

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
