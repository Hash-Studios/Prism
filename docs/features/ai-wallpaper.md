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
| Android and iOS | Pays coins for each image. The image has a Prism watermark. | Pays half the coins for each image, rounded up. No watermark. |

## How it works

### Coin cost

- The quality options and the Generate button show the cost of each tier.
- `AiQualityTier.costFor` sets the cost. Pro pays half, rounded up. Pro never pays 0 for a paid tier.
- Pro gets the half price only while `EconomyConfig.proDiscountActions` lists `aiGeneration`.
- The worker uses the same rule as `spendCoins` in `functions/src/coinsCallables.ts`.
- Pro has no free or included AI runs in the AI tab.
- The one free trial is in onboarding. It uses the fast tier and shows no coin cost. The worker allows one free trial for each account.

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

## Style text in the prompt

The worker adds style text after the user's prompt (`stylePromptSuffix` in `infra/cloudflare/worker/src/ai_style_prompt.ts`). Fal and Gemini requests use the same text.

- Most styles add `<apiValue> style`, for example `anime style`.
- `3d render` adds `stylized 3D render, smooth matte clay-like materials, soft global illumination, rendered CGI look`.
- To add text for another style, add it to the table. Then make that style sample again (see "Making the samples").

## Styles

The style row sits under the Style header. It shows one sample image for each of the 13 styles. Every sample shows the same scene: a lighthouse on a cliff at dusk.

### Row

- Each tile shows the style sample over the style gradient. The tile size does not change.
- The gradient shows while the image loads. It stays when the image fails or the device is offline.
- The row scrolls the selected tile into view when the selection changes. It opens on the selected tile.
- The images use `PrismImageCache`.
- The row does not accept taps while a generation runs.

### See all sheet

The Style header has a "See all" action. It opens `lib/features/ai_wallpaper/views/widgets/ai_style_sheet.dart` (`showAiStyleSheet`).

- The sheet title is "Choose a style". The subject line is under the title.
- The sheet shows a 2-column list of 9:16 previews. The style name is under each preview.
- The current style has the accent ring and a tick.
- A tap selects the style and closes the sheet. The row scrolls to the selected tile.
- The sheet does not open while a generation runs.

### Onboarding

The AI step (`lib/features/onboarding_v2/src/views/pages/f3_ai_generate_page.dart`) shows the same tile row under the prompt chip.

- A tap sends `OnboardingV2Event.aiStyleSelected`.
- The bloc builds a new prompt for that style.
- The row is off while the image generates and after a success. It works again after a failure.

### Analytics

| Event | Fields |
|---|---|
| `ai_style_sheet_opened` | `style` |
| `ai_style_picked` | `style`, and `source` (`row`, `sheet` or `onboarding`) |

## Style samples

The app loads one sample image for each style and size. The style list is in `lib/features/ai_wallpaper/domain/entities/ai_style_preset.dart`.

| Size | Stored size | Used by |
|---|---|---|
| `tile` | 288x360 | Style row tile |
| `sheet` | 540x960 | See all sheet |

URL pattern:

`https://prismwalls.com/api/ai/assets/ai/studio/style-samples-v1-<slug>-<tile|sheet>.webp`

- The slug is the style API value. Every run of characters that is not `a-z` or `0-9` becomes `-`. "mesh gradient" becomes `mesh-gradient`. "space art" becomes `space-art`.
- The key is flat: `ai/studio/<name>`. The worker studio upload route accepts only flat `ai/studio` keys. So the version is part of the name.
- `AiStylePreset.sampleVersion` holds the version (`v1`). The script uses the same version. To replace all samples, bump both.

### Making the samples

The script `tool/ai_style_samples.mjs` makes the samples. Its test, `tool/ai_style_samples.test.mjs`, runs in `make guard-test`.

- It calls `POST /api/ai/studio/generations` on the worker. The model is `fal-ai/bytedance/seedream/v5/lite/text-to-image`, the balanced tier model. The studio route refuses the fast tier Z-Image model.
- It makes each image at 1080x1920. The prompt is `<subject>, <style text>`. The style text comes from `stylePromptSuffix` in `infra/cloudflare/worker/src/ai_style_prompt.ts`, the same text the worker adds to app generations.
- It costs about $0.04 an image, or $0.52 for all 13. It counts against the Studio budget (`STUDIO_DAILY_BUDGET_USD`, 2 USD a day).
- It needs Node.js 24, the repository CI runtime. Generation and upload also need `STUDIO_SECRET` and `sharp`. Run `cd functions && npm ci` first.
- It is idempotent. It skips files that already exist in R2 (HEAD check). It reuses raw images in `build/ai-style-samples/raw`. The worker replays a finished generation id, so it makes no second fal call.
- To redo one style before upload, add its slug to `SEED_OVERRIDES` in the script. A new seed gives a new generation id. Seedream 5 Lite takes no seed input, so the seed only names the attempt.
- A seed change does not replace an uploaded sample. The script skips files that exist, and the URL is cached as immutable.
- Before the samples ship in a release, `--replace=<slug,slug>` bypasses the uploaded-file check for those styles. Give each one a new seed to get a new raw image, because the local cache and worker replay the existing generation id. Keep `--replace` on both the `--skip-upload` review run and the upload run.
- After the samples ship, bump `VERSION` in the script and `AiStylePreset.sampleVersion` together to replace them.
- `--only=<slug,slug>` limits the styles. Every `--replace` slug must be included when `--only` is set.

Steps:

1. Run a dry run. It needs no secret and spends nothing. It lists the 13 styles and 2 sizes, and what exists.

```sh
node tool/ai_style_samples.mjs --dry-run
```

2. Generate and convert. The files go to `build/ai-style-samples/v1` for review.

```sh
doppler run --project prism --config prd -- node tool/ai_style_samples.mjs --skip-upload
```

3. Upload after review.

```sh
doppler run --project prism --config prd -- node tool/ai_style_samples.mjs
```

### Debug override

Debug builds only. Pass `--dart-define=AI_STYLE_SAMPLES_LOCAL=true` (`Env.aiStyleSamplesLocal`). The app then loads `http://localhost:8765/style-samples-v1-<slug>-<size>.webp`. Release builds ignore it.

1. Run `python3 -m http.server 8765` in `build/ai-style-samples/v1`.
2. On the Android emulator, run `adb reverse tcp:8765 tcp:8765`. The iOS Simulator reaches the host `localhost` directly.
3. Run the app with `RUN_ARGS='--dart-define=AI_STYLE_SAMPLES_LOCAL=true'`. Debug builds allow cleartext to localhost.

## Limits

- "Try another" does not use the image. A true image-based refine needs a worker change.
- A timeout retry helps only when the worker has the charge check (`ai-charge.md`). Before that, a retry can make a second image.
- `AI_REQUIRE_CHARGE` is off at first. Old app builds send no `chargeTxId` and still work until the owner turns the flag on.

## How to test

1. Run `fvm flutter test test/features/ai_wallpaper`.
2. The repository tests check the body, the retry and the error code. The page tests check the copy, the sign-in sheet and the charge id.
3. Manual: with a test account, generate an image. Then turn off the network in the middle of a request and check that the app shows the error and refunds the coins.
