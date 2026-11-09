# Feature hints

A feature hint is a small callout next to a real control. It has one sentence and a **Got it** button. It shows one time, when the feature can help the user. It points at features that already exist. It does not change them.

- App: `lib/features/hints/`.
- Platforms: Android and iOS. The Live Photo hint is on iOS only, because its button is on iOS only.
- Plans: all plans. Guests get no Save to folder hint.

## The hints

Each hint names the analytics event it must move. When that event fires, the hint is done and never shows.

| Id | Control | Shows after | Copy | Event it moves |
|---|---|---|---|---|
| `folder_hold` | Heart on wall detail (signed in) | 3 views without a save to a folder | Hold the heart to save this wallpaper to a folder. | `wall_saved_to_folder` |
| `variant_dots` | Colour variant dots on wall detail | 1 view | Tap a dot to see this wallpaper in another colour. | `wallpaper_variant_switched` |
| `photo_search` | Search by photo button in the search bar | 3 views | Find wallpapers that match a photo from your gallery. | `photo_search_started` |
| `follow_category` | Follow button on a category page (not a mood page), not yet followed | 2 views | Follow this category to see when it gets new wallpapers. | `topic_followed` |
| `smart_folders` | New smart folder tile, with 2 or more own folders | 2 views | A smart folder fills itself with wallpapers that match your rules. | `smart_folder_created` |
| `folder_sections` | More options on an own folder with 12 or more wallpapers and no sections | 1 view | Open More options, then Suggest sections, to sort this folder. | `folder_section_suggestions_shown` |
| `photo_fit` | From your photo card on the AI tab | 2 views | Turn your own photo into a wallpaper that fits your screen. | `photo_job_started` |
| `live_photo` | Live Photo button on the Set screen (iOS) | 2 views | Save this wallpaper as a Live Photo for a moving Lock Screen. | `live_photo_export_started` |

### Why these 8

- Folders, smart folders and sections are new and hidden behind a hold or a menu. Users who save walls get the most from them.
- The dots, photo search and From your photo are visible, but small. A user can see them many times and not know what they do.
- Follow and Live Photo bring users back: a daily push, and a Lock Screen that moves.

### Candidates not taken

| Candidate | Reason |
|---|---|
| Day and night | The control is in the hold menu and in Settings. A hint needs a control that is on screen. iOS needs Shortcuts. |
| Open on computer | The row is already in the share sheet the user opened. A hint there sits on top of a sheet. |
| Share to Prism | The entry is the share sheet of the system. Prism has no control to point at. |
| One-handed controls | The only control is in Layout settings. A user there already looks for it. |

## When a hint shows

A surface wraps its control in `FeatureHint(id:, enabled:, child:)`. `enabled` is the condition of the surface, for example "this wall has colour variants".

1. The control must stay on screen for 700 ms. Then it counts as one view.
2. The hint shows when all of these are true:
   - The view count is at the value in the table.
   - The hint did not show before, and the user did not use the feature.
   - **Show tips** is on, `hints_enabled` is not `false`, and the id is not in `hints_disabled_ids`.
   - No other hint is on screen.
   - No Prism sheet is open, and the route of the control is the top route.
   - The whole control is in the safe area of the screen.
   - The budget allows it.
3. A view that cannot show a hint still counts.

### Budget

`HintBudget` in `lib/features/hints/domain/feature_hint.dart`:

- No hint in the first 2 sessions. The session count comes from `AppSessionTracker`.
- At most 1 hint in 24 hours.
- At most 3 hints in 7 days.
- No hint for 10 minutes after another prompt.

### Other prompts

`StartupModalSlot.markPromptShown()` in `lib/core/startup/startup_sheet.dart` records the time of a prompt. `tryClaim()` calls it. These prompts call it too: What's new, the session ended sheet, the daily moment, the daily claim sheet, the badge celebration, the paywall, the seasonal theme announcement, and the Glint toast.

When a prompt shows, a hint on screen closes. The time is also saved on the device, so the 10 minutes stay after a restart.

The Wrapped card and the seasonal theme cards are cards in the Home carousel, not prompts. No hint attaches to the Home feed.

## The callout

- A bubble in `inverseSurface` with `onInverseSurface` text (13 points) and a small arrow to the control. **Got it** uses `inversePrimary`.
- It is below the control when it fits there. Else it is above. It stays 16 points from the screen sides and is at most 320 points wide.
- There is no scrim. A tap outside the bubble closes it, and the tap also goes to what is under it.
- A tap on the bubble closes it too. On the iOS Set screen there is no room under Live Photo, so the bubble is above it, over Save to Photos, until the user taps it.
- It enters with a 240 ms fade and a scale from 0.95. With reduce motion, it shows at once.
- VoiceOver reads the sentence when the hint shows (an announcement). TalkBack reads it from a live region. The hint does not take focus. **Got it** is a button with a 44 point target.
- It is an `OverlayEntry` in the overlay of the route. It is not an `OverlayPortal`, because an `OverlayPortal` can empty the iOS accessibility tree (see `lib/core/widgets/prism/prism_slider.dart`).

## Storage

- Device-wide: `hints.enabled` (Show tips) and `hints.last_prompt_at`.
- Per user: `hints.records.<uid>` (`guest` when signed out). It is JSON: views, shown time and used, for each hint.
- The records do not sync with the account. A sync with the layout preferences needs a Firestore rules change.

## Settings

**Settings** has **Show tips** (on by default) and **Reset tips**. Reset tips clears the records of the current user, so every hint can show again. The budget still applies.

## Remote Config

| Key | Value | Effect |
|---|---|---|
| `hints_enabled` | `true` or `false` | `false` or `0` turns off all hints. Not set means on. |
| `hints_disabled_ids` | Comma list, for example `photo_fit,live_photo` | Turns off these hints. |

These keys are not published. Add them in the Firebase console when they are necessary.

## Analytics

| Event | Fields | When |
|---|---|---|
| `hint_shown` | `hint_id` | A hint shows. |
| `hint_dismissed` | `hint_id`, `method` (`got_it`, `tap_outside`, `interrupted`) | A hint closes. `interrupted` means a prompt, a new route, Show tips off, or the control left the screen. |
| `hint_feature_used` | `hint_id` | The event of the feature fires in the 24 hours after its hint showed. |

To get the effect of a hint, compare the rate of its feature event for users with `hint_shown` against users with no hint.

## Add a hint

1. Add an id to `HintId` and a row to `kHints`, with the views, the feature event and the copy.
2. Add the copy to the 7 ARB files and run `make l10n-gen`.
3. Add the id to the `hint_id` enum in `lib/core/analytics/schema/analytics_events.yaml` and run `make analytics-gen`.
4. Wrap the control in `FeatureHint`. Put the condition of the surface in `enabled`.
5. Add a widget test that the control has the `FeatureHint` with the new id.

## Test

- `fvm flutter test test/features/hints`
- On a device: start a fresh install, open the app 3 times, then open a wall with colour variants. The dots hint shows. Use Reset tips in Settings to see it again (the budget allows one a day).
