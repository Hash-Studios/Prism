# Duo reveal wallpapers

## Verified sources and Prism's crop

The [Apple iPhone Duo specifications](https://www.apple.com/iphone-duo/specs/) list an outer display of 1398 x 2034 pixels.
The inner portrait display is 1878 x 2670 pixels. Prism uses its landscape size, 2670 x 1878, for one full original.
These display specifications were checked on 2026-10-30. They do not define an exact wallpaper file or automatic crop contract.

Apple's [Device Hub guide](https://developer.apple.com/documentation/Xcode/interacting-with-your-app-in-device-hub.md) documents fold controls.
The parent research found iPhone Duo in local Xcode 27.1. A fold command produced a wide screenshot, but hinge readback failed.
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
This implementation worker read that schema without making a generation request. Fast requests retain the canonical target.

## Website publication

The route is `/iphone-duo-wallpapers`.
`web/lib/duo-approved.json` starts empty. Empty output has `noindex` and is absent from the sitemap.
There is no navigation promotion for the empty collection.
After explicit publication approval, add only reviewed public Studio originals with the canonical size and preset ID.
The same build renders both folded and unfolded views on the server, with Prism and store links.
The site uses its current dark gallery, type, spacing, header, and footer.
The preview images require no animation or JavaScript, so reduced motion shows the same content.
Tests inject local data without adding fixtures to the published manifest.

## Deployment order and remaining proof

1. Complete copy integration, shared generator CI checks, model generation, and independent review.
2. Run the full local gates. Recheck exact current diffs after the parallel workers finish.
3. With explicit approval, deploy the worker changes before shipping Duo AI. Verify the existing renderer configuration and quotas.
4. With explicit approval, deploy Functions before the new Studio series runs.
5. With separate explicit approval, run the manual Studio batch. Wait for processing, then review both views in the normal queue.
6. With publication approval, populate the approved manifest. Build and deploy the website only after those approvals.
7. Verify the app on iOS Duo and Android or a foldable if available. Run the separately authorized dev AI generation after review.

The parent owns screenshots and a real device-driven recording through the device panel command and `tool/record_clip.sh`.
Video share export is a follow-up. The current share artifact is a still card with folded and unfolded previews.
Local tests, device proof, hosted CI, deployments, and live behavior are separate gates.
This implementation worker runs no real generations, devices, deploys, production writes, commits, pushes, or PRs.
