# Profile and edit profile

The signed-in user's own profile is a nested dashboard route (`/dashboard/profile`, `ProfileRoute`, `lib/features/public_profile/views/pages/profile_screen.dart`); the same screen renders another user's public profile at `/user/:identifier`. Editing uses a popup panel, `lib/core/widgets/popup/edit_profile_panel.dart`, reached at `/edit-profile` (guarded) or `/dashboard/profile/edit`.

## Sub-features

- `own-profile`: tooltip `Edit profile` (pencil/edit affordance) and tooltip `Menu` (opens a popup menu with `Block user` when viewing someone else's profile).
- `followers` / `following`: tappable counters labeled `Followers` and `Following`, each pushing `FollowersRoute` / `FollowingListRoute`.
- `edit-profile` panel: tooltip `Close`, `Change cover photo` / `Remove cover photo`, `Change profile photo`, text fields `Name`, `Username`, `Bio` (hint `Tell people about yourself…`, tooltip `Remove bio`), and a link section (`Link type`, tooltip `Remove link`).
- `share-profile`: `/share-prism` (guarded when reached from own profile), see `lib/features/session/views/pages/share_prism_screen.dart`.
- `block-user`: from the `Menu` popup on someone else's profile.

## How to get to it (user POV)

- Tap `Your profile` in the top app bar (see `features/home-feed.md`) to reach your own profile.
- Tap a user's name/avatar anywhere in the app (search results, a wallpaper's author, a comment) to reach `/user/:identifier`.
- On your own profile, tap the edit tooltip to open the edit panel.
- Tap `Followers` or `Following` counters to see the respective list.

## Driving it with the helper

Preconditions:

- Signed-in human for own-profile edit, share, and any guarded action. Signed-out or another user's profile is fine for read-only viewing.

- **Own profile.** Snapshot `--tag profile-own`. Assert tooltip `Edit profile`.
- **Someone else's profile.** Assert tooltip `Menu`; open it and assert `Block user`. Do not actually block a real account; this is a real, visible moderation action. Only exercise it against a disposable test account, and confirm with the human first.
- **Followers / Following.** Tap `Following`; assert the list route opens (label `Following` per `profile_screen.dart:635`). Tap `Followers` similarly (`profile_screen.dart:655`).
- **Edit profile.** Open the panel; assert `Name`, `Username`, `Bio` fields and the `Change profile photo` / `Change cover photo` affordances. Typing into `Name`/`Bio` and closing with `Close` without saving is a safe, reversible check. Saving a real change to a real account's profile needs the human's go-ahead.
- **Share profile.** From own profile, reach `/share-prism`; confirm it renders a shareable link/QR without actually posting it anywhere.
- **Proof.** Snapshot own profile, another user's profile with the menu open, and the edit panel.

## Gotchas

- `EditProfilePanel` lives under `lib/core/widgets/popup/`, not under a `profile` feature folder; it is shared UI, not screen-scoped.
- Following a real account, blocking a real account, or changing a real profile are all real, user-visible actions. Prefer read-only assertions (labels present, fields editable) over completing them, unless the recipe's whole point is that action and the account is a disposable QA account.
- `Bio`'s hint text ends with a real ellipsis character (`…`), not three periods; match it exactly if asserting on it.
