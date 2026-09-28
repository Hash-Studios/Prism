# Setups

"Setups" are curated home-screen layouts (wallpaper + icon pack + widgets) that users browse and upload. Browse tab route `/dashboard/setups` (`SetupRoute`, `lib/features/setups/views/pages/setup_screen.dart`). Upload and review live under the same `lib/features/setups` folder, mostly behind `_signedInGuard`.

## Sub-features

- `browse` swipes/pages through setups full-screen; a `Previous setup` accessibility label exists for backward navigation (`setup_screen.dart:236`).
- `upload-setup` (`/upload-setup`, guarded) has category tabs `Link`, `Upload`, `App`, `Widgets`, `* Icons` (`upload_setup_screen.dart`).
- `setup-guidelines` (`/setup-guidelines`, guarded): rules shown before/around upload.
- `review` (`/review`, guarded, `review_screen.dart`): review status / moderation state for the user's own submissions.
- `draft-setup` (`/draft-setup`, guarded): an in-progress, unsubmitted setup.
- `edit-setup-details` (`/edit-setup-details`, guarded): edit metadata on an owned setup.
- `setup-view` (`/setup-view`) and `profile-setup-view` (`/profile-setup-view`): read-only detail screens reached from browse or from a profile's setup grid.
- `share-setup-view` (`/setup/:setupName`): the deep-link/share target for a single setup (see `features/deep-links.md`).
- `favourite-setups`: `/fav-setups` (list) and `/fav-setup-view` (guarded detail).

## How to get to it (user POV)

- Tap the `Streak`... no: tap the `Setups` destination is not on the bottom nav (only `Home`, `Search`, `Streak`, `Collections` are); reach setups via the dashboard's `setups` nested route, normally through an in-app link, the FAB (`Upload`), or a profile's setups grid. Confirm the actual entry affordance with `describe` on the dashboard shell before assuming a specific tap path; it was not pinned down while building this map.
- Tap the `Upload` FAB (`prism_fab.dart`) from Home to reach `/upload-setup` or `/upload-wall` (the FAB's own menu was not read in detail; confirm with `describe`).
- Open a shared setup link (`prismwalls.com/setup/<name>` or `/share-setup/<name>`).

## Driving it with the helper

Preconditions:

- Signed-in human for anything under `_signedInGuard` (upload, guidelines, review, draft, edit, favourite detail). Signed-out is fine for `setup-view` and the share deep link.

- **Browse.** Land on the setups browse screen, snapshot `--tag setups-browse`. Swipe/tap to move between setups; assert the `Previous setup` label exists once you are past the first item.
- **Upload tabs.** On `/upload-setup`, assert the five category tabs `Link`, `Upload`, `App`, `Widgets`, `* Icons` render. Do not submit a real upload unless the recipe is specifically about the upload pipeline; a submitted setup goes through real moderation (`admin-review` routes) and is visible to other users once approved.
- **Guidelines.** Confirm `/setup-guidelines` renders before or alongside upload; exact copy was not read for this map.
- **Review status.** `/review` should reflect the signed-in user's own submissions (empty state if they have none).
- **Favourite a setup.** From `setup-view`, favouriting should make it reappear under `/fav-setups`.
- **Proof.** Snapshot the browse screen, the upload tab bar, and (if driven) the guidelines/review screens.

## Gotchas

- This feature spans two folders: `lib/features/setups` (screens/routes) and depends on shared widgets from `lib/core/widgets`. Do not assume every button lives in the page file you are looking at.
- Uploading a setup or a wallpaper (`/upload-wall`) is a real, moderated content submission, not a sandboxed test action. Treat it like posting as a real user: confirm with the human before submitting anything that is not throwaway test content.
- The FAB's upload menu (setup vs. wallpaper vs. AI) and the exact tap path from Home into `/upload-setup` were not traced in detail for this map. Run `describe` on the FAB's expanded state before writing a tap recipe.
