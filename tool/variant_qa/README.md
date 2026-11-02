# Colour variant local QA

This recipe proves colour variants on the Android emulator against a disposable `demo-prism` backend. It reuses the weekly challenge QA runtime (`tool/weekly_challenge_qa/README.md`). Read that README first. Its safety rules apply here.

The runtime root is `/tmp/prism-weekly-qa-variants`.

## What it adds

- The real `onWallVariantWritten` trigger.
- `qaVariantSubmitCheck`, a create trigger that runs the real `checkSubmittedVariantOf`. This is the variant step of `onWallSubmitted`. The rest of `onWallSubmitted` pushes to admins, so it does not run here.
- Three colourways of the fixture image (red, blue and green), and one image with a different shape.

## Steps

Build the functions first: `npm --prefix functions run build`.

```sh
node tool/variant_qa.cjs prepare
node tool/variant_qa.cjs serve        # terminal 1
node tool/variant_qa.cjs emulators    # terminal 2
node tool/variant_qa.cjs seed         # after both are ready
```

`seed` creates `qa-viewer`, `qa-creator-a` and `qa-creator-b`, then these walls:

| Wall | Owner | Result |
|---|---|---|
| `qa-var-root` | creator A | Approved red wall. The set is named after it. |
| `qa-var-blue`, `qa-var-green` | creator A | Approved through the real trigger. They join the set. |
| `qa-var-wide` | creator A | Different shape. The submit check drops the link (`aspect_ratio`). |
| `qa-var-foreign` | creator B | Links to creator A's wall. The submit check drops it (`not_owner`). |
| `qa-plain` | creator A | Approved wall with no variants. |

`seed` waits for each trigger, then checks the set and writes `variant-evidence.json`. Run `node tool/variant_qa.cjs assert` to check again.

## App builds

```sh
node tool/variant_qa.cjs build-apk
```

The build uses the identity in `/tmp/prism-weekly-qa-variants/dart-defines.json`. Set `PRISM_LOCAL_QA_USER` to `creator` for creator A, or `viewer` for the viewer. Build once for each account.

Reverse the ports, then open a wall:

```sh
for p in 19371 19372 19373 19375; do adb -s emulator-5580 reverse tcp:$p tcp:$p; done
adb -s emulator-5580 shell am start -a android.intent.action.VIEW -d 'prism://share/qa-var-root?source=prism'
```

The full picture of a wall comes from the `wallpaperPreview` function, which this runtime does not serve. The detail shows the fixture thumbnail instead.

Uploads stop at the composer. This runtime has no upload callables.
