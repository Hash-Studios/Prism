# AI wallpaper

AI wallpaper makes a wallpaper from a text prompt and spends coins per image. The page is `lib/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart`, titled `AI wallpaper`. It is not a tab. It is a page pushed over the shell (`AiTabRoute`, path `/ai`, `lib/core/router/app_router.dart`).

## Sub-features

- `prompt`: field with the hint `Describe a scene to generate.` Buttons `Shuffle` and `Scene idea` fill an example.
- `style`: picker, each item labelled `Style: <name>`.
- `quality`: tiers labelled `<Fast|Balanced|Quality>, <N> coins`. Pro users pay half.
- `watermark-note`: non-Pro users see `Free images carry a Prism watermark. Pro removes it.`
- `generate-bar`: bottom button `Generate` with the cost on a second line (for example `Generate\n10`), or `Earn coins` when the balance is too low.
- `result-actions` (`ai_result_actions.dart`): `Save`, `Try another`, icon buttons `Set as wallpaper` (hidden on iOS), `Share`, and `Submit for community review`.
- `try-another`: sheet `Try another version` with a field hinted `Darker sky, warmer palette, softer edges…`, `Close`, and button `Generate another` (`ai_sheets.dart`).
- `submit-sheet`: sheet `Share with the community?` with `Submit for community review` and `Cancel`.
- `history`: section `Recent`, items `Generation from <MMM d>`.
- `coin-chip`: the app bar chip pushes `RewardsRoute` (see `features/rewards.md`).
- `blocked-states`: `AI wallpaper is off for now`, `AI wallpaper is opening gradually`, or the `Sign in to use AI wallpaper` prompt.
- `live-activity`: on iOS, a Live Activity shows during generation.

## How to get to it (user POV)

- Tap the `Upload` FAB, then the `AI wallpaper` row in the `Create` sheet (`lib/features/navigation/views/widgets/upload_bottom_panel.dart`).
- Or open Rewards and tap the `AI wallpaper` tile under `Use your coins`.
- Or open `prism://ai`.

## Driving it with the helper

Preconditions: a signed-in human. A real generation also needs coins.

- **Landing.** Open the page. Snapshot `--tag ai-wallpaper`. Assert the title `AI wallpaper` and the prompt field. The hint `Describe a scene to generate.` shows only when the field is empty; with text the field reads `Text field`.
- **Prompt helpers.** Tap `Shuffle` and `Scene idea`. Confirm the prompt changes. Do not submit.
- **Pickers.** Assert one `Style: <name>` item. Assert tiers `Fast, N coins`, `Balanced, N coins`, `Quality, N coins`.
- **Coin chip.** Tap the chip. Assert Rewards opens. Go back.
- **Blocked state.** If the page shows `AI wallpaper is off for now` or the rollout text, report it. Do not call it a pass.
- **Generate (needs approval).** Tap `Generate` only after the human approves the coin spend. Prefer the cheapest tier. Then assert `Save`, `Try another`, `Share`.
- **Submit sheet (needs a result).** Tap `Submit for community review`. Assert `Share with the community?`. Tap `Cancel`.

## Gotchas

- Never tap `Generate`, `Generate another`, or the submit button in a verification run unless the human approves. They spend coins or post content to moderators.
- `Set as wallpaper` is hidden on iOS (`hideSetWallpaperUi`). Its absence there is correct.
- Submissions go into the admin review queue (`/admin-review`, admin guard). Treat a submit like posting real content.
- The sheet button and the icon button share the label `Submit for community review`. Use `describe` to tell them apart.
- Onboarding has its own first AI step (`features/onboarding-signin.md`). It is a different screen.
