# Creator desktop version local QA

This recipe proves creator desktop versions on the Android emulator against a disposable `demo-prism` backend. It reuses the weekly challenge QA runtime (`tool/weekly_challenge_qa/README.md`). Read that README first. Its safety rules apply here.

The runtime root is `/tmp/prism-weekly-qa-desktop`.

## What it adds

- The real `submitDesktopVersion` and `reviewDesktopSubmission` callables.
- A local R2: objects are files under `r2/` in the runtime. `serve` serves the public previews from it.
- Preview URLs on the fixture server (`https://localhost:19375/previews/...`). The production preview base cannot carry a port, so the runtime replaces `desktopThumbUrl` and `isPreviewUrl`. Nothing else changes.
- Four gallery images: `desktop-dusk-1610` (2560 x 1600), `desktop-dawn-169` (1920 x 1080), `desktop-portrait` (1080 x 1920) and `desktop-small` (1600 x 1000).

Pushes cannot leave the runtime. The approve and reject pushes fail, and the creator inbox entry shows the copy.

## Steps

Build the functions first: `npm --prefix functions run build`.

```sh
node tool/desktop_qa.cjs prepare
node tool/desktop_qa.cjs serve        # terminal 1
node tool/desktop_qa.cjs emulators    # terminal 2
node tool/desktop_qa.cjs seed         # after both are ready
```

`seed` creates the creator `qa-creator-a`, the admin `qa-admin` (admin claim) and two approved walls of the creator: `walls/qa-desk-approve` (Dusk ridge) and `walls/qa-desk-reject` (Quiet dunes).

## App builds

```sh
node tool/desktop_qa.cjs build-creator   # /tmp/prism-weekly-qa-desktop/prism-creator.apk
node tool/desktop_qa.cjs build-admin     # /tmp/prism-weekly-qa-desktop/prism-admin.apk
```

Install one build at a time. Reverse the ports and push the gallery images:

```sh
for p in 19371 19372 19373 19375; do adb -s emulator-5554 reverse tcp:$p tcp:$p; done
ANDROID_SERIAL=emulator-5554 node tool/desktop_qa.cjs gallery
adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d 'prism://share/QADESKA001?source=prism'
```

## Flow

1. Creator build. Open Dusk ridge. Tap **Add a desktop version**. Pick `desktop-portrait`, then `desktop-small`: each shows its error. Pick `desktop-dusk-1610`. The phone wall and the wide image show side by side. Tap **Submit for review**. The button now reads **Desktop version in review**.
2. Submit `desktop-dawn-169` for Quiet dunes the same way.
3. Admin build. Open the review screen, **Desktop** tab. Approve Dusk ridge. Reject Quiet dunes with a reason.
4. Creator build. Dusk ridge shows the **Desktop version** chip and the **Watch set** sheet has the desktop item. The inbox has "Your desktop version is live" and "Desktop version not approved".

Run `node tool/desktop_qa.cjs evidence` at any point. It writes `desktop-evidence.json` with each submission, the wall links, the stored objects and the creator inbox.
