# Upload

Upload lets a user submit their own wallpaper for review. It starts at the bottom-nav FAB, goes through an edit step, an upload screen and the review list (`lib/features/wallpaper_upload/`, `lib/features/navigation/views/widgets/`).

## Sub-features

- `fab`: button labelled `Upload` (`prism_fab.dart`). Signed out, it asks for sign-in first, then opens the panel.
- `create-panel`: sheet titled `Create` (`upload_bottom_panel.dart`) with rows `Upload wallpaper` (subtitle `From your gallery`), `AI wallpaper` (badge `New`) and, if a draft exists, `Resume saved upload`. A free-quota line (`3 of 3 free uploads left this week`) also shows.
- `edit`: `/edit-wall` (`edit_wall_screen.dart`). Title `Edit wallpaper`: ratio chips (`9:18`, `9:16`, `9:21`, `9:19.5`), flip and rotate, `Saturation`, `Brightness`, `Contrast`, and `Save`.
- `upload`: `/upload-wall` (`upload_wall_screen.dart`). Stages `Preparing wallpaper`, `Ready to submit`, `Uploading wallpaper`, `Submitting wallpaper`, then `Submitted for review`. The screen is titled `Upload wallpaper`, lists a checklist under `Ready to submit`, and has an `Upload` button. Back opens `Leave this upload?` with `Keep draft`, `Discard`, `Cancel`. On a failed submit a ghost button `Check review status` shows.
- `review`: `/review`, the user's submissions (`review_screen.dart`).

## How to get to it (user POV)

- Tap `Upload` in the bottom nav, then a row in `Create`.
- `AI wallpaper` leads to the AI flow. See `features/ai-wallpaper.md`.
- Settings row `Review status` opens `/review` directly (`settings_screen.dart`).
- `/upload-wall`, `/edit-wall`, `/review` all have `_signedInGuard` (`app_router.dart`). The `Check review status` text is not a panel row. It only shows after a failed submit.

## Driving it with the helper

Preconditions: signed in (ask the human). For gallery pick, put a photo in the simulator first: `xcrun simctl addmedia <udid> <file>`.

- **Panel.** Tap `Upload`. Assert `Create`, `Upload wallpaper`, `AI wallpaper`. Snapshot `--tag upload-panel`.
- **Pick.** Tap `Upload wallpaper`. The system picker says `Select up to 3 photos.` Tap a photo, then the check button at the top right. Assert `Edit wallpaper`. Snapshot.
- **Stages.** Tap `Save`. Assert `Upload wallpaper` and `Ready to submit`. Snapshot `--tag upload-ready`. STOP here: tap Back, then `Discard`, so no draft stays.
- **Review.** Open Settings, tap `Review status`. Snapshot the list.

## Gotchas

- NEVER submit a real upload without the human's go-ahead. It creates a real review item and may notify admins.
- Free users have a weekly upload quota (`wallpaperUploadFreeQuotaMessage`). The pick limit depends on premium.
- Leaving mid-flow may save a draft. Then `Resume saved upload` shows next time.
- Android uses the system photo picker. The label text differs by OS version, so use `describe`.
- The photo picker does not empty the accessibility tree. Before PR #746, the `Edit wallpaper` sliders did, so the tree stayed empty until a relaunch (2026-10-29, iOS 27). If you see an empty tree on a build without that fix, relaunch before the next recipe.
- A tap on the `Upload wallpaper` row by its tree label once landed above the sheet and closed it (wrong frame). If the picker does not open, screenshot and tap the row by its position.
- Confirm every label with `describe` before tapping.
