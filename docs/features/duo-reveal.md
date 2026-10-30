# Duo reveal wallpapers

## Verified sources and Prism's crop

The [Apple iPhone Duo specifications](https://www.apple.com/iphone-duo/specs/) list an outer display of 1398 x 2034 pixels.
The inner portrait display is 1878 x 2670 pixels. Prism uses its landscape size, 2670 x 1878, for one full original.
These display specifications were checked on 2026-10-30. They do not define an exact wallpaper file or automatic crop contract.

Apple's [Device Hub guide](https://developer.apple.com/documentation/Xcode/interacting-with-your-app-in-device-hub.md) documents fold controls.
Local Xcode 27.1 includes iPhone Duo. During research, a fold command produced a wide screenshot, but hinge readback failed.
The local screenshot was 2853 x 2007. That screenshot does not establish the physical panel size or complete fold proof.

No verified exact iOS wallpaper crop was found. The user approved Prism's `prism-right-v1` preset.
This is a Prism preview, not Apple's automatic crop. The quiet top quarter is a composition choice, not an Apple safe area.

The folded source rectangle uses these expressions without rounding:

```text
height = 1878
width = 1878 * 1398 / 2034
x = 2670 - width
y = 0
```

An arbitrary image first center-covers the canonical canvas. Preview then crops the right side.
Only rasterization rounds coordinates. Saving always keeps the full original.
After a successful Photos save, the app guide explains manual alignment and asks you to check the system wallpaper preview.
Android keeps its normal home, lock, and both options. The Android system can crop differently.

## Source and generated files

`shared/duo_reveal.json` owns the geometry and factual source URL.
`node tool/generate_duo_reveal.mjs` produces the Dart spec and the three TypeScript specs at the contract paths.
`node tool/generate_duo_reveal.mjs --check` detects drift.
The fractions derive from the source dimensions, not rounded copies.
The finite phrase guard comes from `shared/duo_banned_phrases.json` and uses Unicode normalization and whole phrases.
It checks catalog fields and the provider boundary. It is not proof of originality.

All new copy lives in the seven app ARBs.
`node tool/generate_duo_web_copy.mjs` generates `web/lib/duo-copy.generated.ts` from the English `duoWeb` keys.
It does not edit ARBs or use a separate fallback.
`make duo-check` checks both generated outputs and runs as part of `make ci`.

## Studio candidates and review

The `duo-reveal` series has 24 original subject pairs across animals, objects, science fiction, cute scenes, and visual jokes.
Only an explicit manual series selection can plan it. Weights cannot add it to a scheduled or unfiltered manual run.
It shares the existing 30-candidate UTC daily cap with all other Studio runs. Cooldown and configured lower caps still apply.
An accepted candidate enters the normal `review: false` admin queue with `duo` and `duo-reveal` tags.
It cannot receive an automatic Drop reservation. Approval is a separate human action.

Reviewers must inspect both views for the reveal, composition, text, logos, recognizable people, brands, and existing characters.
Reject weak reveals and copied subjects. The approved count can be less than 24.
The app can ship with no approved walls. Empty rows stay hidden.

From `functions/`, this command checks the actual CLI, model, dimensions, and 24-candidate plan without writes:

```sh
npm run studio:run -- --count 24 --series duo-reveal --dry-run
```

After separate approval, removing `--dry-run` plans a real run and triggers generation.
Do not run that command as a local verification step.
The dry run does not read production config, remaining daily capacity, or recent subject use.
The actual run must have an enabled `studioConfig/current`, a Studio identity, budget, and at least 24 daily slots.
Keep the portrait config dimensions intact. Duo candidates override their dimensions to 2688 x 1888.

The default model in `studio/config.ts` is `openai/gpt-image-2.5/sunburst/text-to-image`.
The worker's `FAL_MODELS` prices it at $0.07 per image, so 24 dispatched images cost $1.68 before extras.
That is a code-configured estimate, not a provider invoice or a live configuration read.
Vision, storage, browser rendering, transfers, retries, and other runs cost extra.
The existing worker Studio defaults cap spend at $2 per day and $60 per month. Runtime configuration can lower or override them.
Studio attempts are capped at three. A dispatched provider call can consume budget even if later processing fails.

## Exact output and consumer AI

Both generation paths target 2670 x 1878. GPT Image requires multiples of 16, so it receives 2688 x 1888.
Studio checks the decoded wide image without weakening portrait gates. Existing sharp processing center-covers it to exactly 2670 x 1878.
It does not upscale smaller results.

Consumer AI accepts optional `format: 'duo-reveal'`, `foldedPrompt`, and `revealedPrompt`.
Each field must contain 1 to 160 trimmed characters. The server composes the full layout prompt after validation.
It does not apply the legacy 160-character limit to the composition.
With no format, the old phone request remains unchanged.
The existing tier, coin charge, refund evidence, free-trial, provider budget, and user cap rules remain in force.
Records and charged private staging retain the flat optional fields. Variations retain them too.
No prompt text is added to analytics.

The worker uses its existing Browser Rendering screenshot API for exact original normalization, with the watermark disabled for that pass.
It decodes the actual image dimensions before accepting a result and refuses to enlarge a small result.
The canonical original is stored before the normal watermarked public copy.
`BROWSER_RENDERING_ACCOUNT_ID` and `BROWSER_RENDERING_API_TOKEN` are prerequisites. Missing configuration fails before the provider runs.
Renderer failures or undersized provider output fail generation through the existing charge failure path.
No dependency was added. Provider output sizes and browser rendering still need one authorized live dev proof.
The [fal Z Image Turbo OpenAPI schema](https://fal.ai/api/openapi/queue/openapi.json?endpoint_id=fal-ai/z-image/turbo)
accepts positive integer custom edges up to 14142. Its schema does not impose a 2048-edge cap or an alignment multiple.
Schema validation does not prove live provider output. Fast requests retain the canonical target.

## Website publication

The route is `/iphone-duo-wallpapers`.
`web/lib/duo-approved.json` starts empty. Empty output has `noindex` and is absent from the sitemap.
There is no navigation promotion for the empty collection.
After explicit publication approval, add only reviewed public Studio originals with the canonical size and preset ID.
The same build renders both folded and unfolded views on the server, with Prism and store links.
The site uses its current dark gallery, type, spacing, header, and footer.
The preview images require no animation or JavaScript, so reduced motion shows the same content.
Tests inject local data without adding fixtures to the published manifest.

## Deployment order and proof

1. Complete local checks and independent reviews before device proof.
2. Verify the app on iOS Duo and Android, plus a foldable if available. Run the authorized dev AI generation against the changed worker, not the old deployed version.
3. With explicit approval, deploy the worker changes before shipping Duo AI. Verify the existing renderer configuration and quotas.
4. With explicit approval, deploy Functions before the new Studio series runs.
5. With separate explicit approval, run the manual Studio batch. Wait for processing, then review both views in the normal queue.
6. With publication approval, populate the approved manifest. Deploy the website only after those approvals.

Proof must include screenshots, a share card, empty and populated local web fixtures, and a real device-driven reveal recording.
Use the device panel command for capture and the conversion settings in `tool/record_clip.sh` for the clip.
Video share export is a follow-up. The current share artifact is a still card with folded and unfolded previews.
Local tests, device proof, hosted CI, deployments, and live behavior are separate gates.
No deployment or real Studio batch is authorized by the implementation task.

## Verification on 2026-10-30

The reviewed feature commit is `aa7578930`. Documentation changes do not change the built app.

- Full Flutter suite after the fixing review: 8,125 passed, 5 skipped, no failures.
- Functions build and full suite: 2,198 passed, 16 skipped, no failures.
- Worker suite: 130 passed. Wrangler dry-run bundle passed; nothing was deployed.
- Web production build, type check, and all three SSR/manifest tests passed.
- Geometry, copy, analytics, localization, and remaining local guards passed.
- `make ci` is not green: its strict analysis step stops on 315 existing info-level findings. None maps to changed lines. The gate was not weakened.
- Doppler dev debug builds passed for iOS Simulator and Android, with `SENTRY_UPLOAD=false`.

The Sol fixing review added regressions and fixed five issues: replay metadata contamination, short-screen control overflow,
lost Apply analytics, duplicate Apply preparation, and stale-session error messages.
The parent reran the full Flutter and Functions suites afterward.
The Astra final review found no new confirmed defects and made no code changes.

### Captured proof

[Published evidence and source notes](https://github.com/Hash-Studios/Prism/tree/qa/screenshots/qa-2026-10-30/duo-reveal) include the before/after screenshots, share PNG, and reveal clip.

- iPhone Duo Simulator: the real Photos picker loaded a local 2670 x 1878 geometry fixture. Phone, folded, and unfolded previews were captured. The clock stays visible and the right-side preset reveals the second shape. This is a QA fixture, not generated or approved catalog content.
- Pixel Fold emulator: the real Pexels catalog wallpaper `3244513` was opened through the normal preview route. Both preview states worked on the inner and cover displays. Closing the emulator hinge retained preview state. Home, Lock, and Both remained selectable. Android's system-crop notice is visible. This is an existing wide wallpaper, not approved Duo content.
- Reduced motion: Android animations were disabled for an end-state capture, then restored. Widget tests prove the zero-duration transition; the screenshot alone does not measure timing.
- Share card: the production renderer produced a 1080 x 1920 PNG from the local geometry fixture. It shows folded above unfolded and the Get it on Prism CTA. This proves the renderer, not native share-sheet export.
- Reveal clip: an actual iOS app interaction was recorded with the device-panel `agent-device` command. The conversion settings from `tool/record_clip.sh` produced a 1080 x 1920, 5.03-second clip. That script did not perform the capture.

### Open proof gates

- Live dev AI generation needs an owner-authenticated QA session and a way to exercise the changed worker. Fresh QA devices are signed out, and the app endpoint is currently the production URL. No auth bypass or request to the old deployed worker was used as substitute proof.
- Successful iOS Photos save followed by the three-step Duo guide still needs a device run. Tests cover full-original bytes, success-only presentation, and failed-save retry.
- Native share-sheet export still needs a device run.
- Actual Android wallpaper application is not proven. The device helper timed out after Set as wallpaper; its one diagnostic retry reported `adb: device 'emulator-5586' not found`. The fleet lease was closed rather than replaced or bypassed.
- iOS hardware fold and system wallpaper alignment remain unverified. An in-app Fold/Unfold toggle is not proof of either.

These are release gates, not claims covered by the screenshots or local tests.
