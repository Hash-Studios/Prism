# AI wallpaper

The AI tab (route `/ai`, `AiTabRoute`, `lib/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart`, app bar title `AI wallpaper`) generates a wallpaper from a text prompt, spending coins per generation tier.

## Sub-features

- `prompt`: text field with placeholder-style hint `e.g. misty peaks at dawn, soft light, no text on image`; tooltip `Shuffle a new example description` refreshes the example; tooltip `Use this scene in your description (editable)` inserts a suggested scene.
- `tier-select`: coin-cost tiers, accessibility label `<tier label>, <coinCost> coins`.
- `generate`: spends coins for a generation; result actions are `Set`, `Save`, `Refine`.
- `refine`: opens a refinement field, hint `Darker sky, warmer palette, softer edges…`, button `Generate refinement`.
- `submit-for-review`: button `Submit for review`, semantic label `Submit wallpaper for community review`, with a confirm dialog (`Cancel` to back out).
- `history`: past generations, semantic label `Selected generation` for the current one and `Past generation` for others.
- `coin-balance`: tapping the balance chip here also opens `/coin-transactions` (see `features/coins-streak.md`).

## How to get to it (user POV)

- Tap the AI tab (reached from wherever the app surfaces it; it is a top-level `AutoRoute`, not nested under `/dashboard`, so it may be its own nav entry or reached via the FAB, confirm with `describe`).

## Driving it with the helper

Preconditions:

- Signed-in human with enough coin balance to cover at least the cheapest tier, if the recipe needs to complete a real generation.

- **Landing.** Snapshot `--tag ai-wallpaper`. Assert the app bar title `AI wallpaper` and the prompt field's hint text.
- **Prompt helpers.** Tap `Shuffle a new example description`; confirm the hint/example text changes. Tap `Use this scene in your description (editable)`; confirm it populates the prompt field without submitting.
- **Tier select.** Assert at least one tier renders with a `<label>, <coinCost> coins` accessibility label.
- **Generate.** This spends real coins from the signed-in account. Only complete it when the recipe is specifically about generation, and prefer the cheapest tier. After a result appears, assert `Set`, `Save`, `Refine` all render.
- **Refine.** Tap `Refine`; assert the refinement field with hint `Darker sky, warmer palette, softer edges…` and the `Generate refinement` button. Refining spends more coins; same caution as `generate`.
- **Submit for review.** Tap `Submit for review`; assert the confirm dialog, then `Cancel` out unless the recipe is specifically about the community-review submission pipeline (a real, moderated, visible-to-others content submission).
- **Proof.** Snapshot the prompt screen, the tier picker, and (if generated) the result screen with `Set`/`Save`/`Refine`.

## Gotchas

- Generation and refinement cost real coins against the signed-in account. Do not spend a human's coin balance without checking first; prefer a disposable QA account with coins already granted.
- `Submit for review` puts a wallpaper into the same moderation/admin-review pipeline as manual uploads (`/admin-review`, admin-guarded). Treat a completed submission like posting real content.
- This onboarding flow has its own, separate "generate a first AI wallpaper" step (`features/onboarding-signin.md`, step `ai-generate`). Do not conflate the two; they are different screens with different entry points, even though both call the same underlying generation capability.
