# Profile and edit profile

Every profile is `ProfileRoute` at `/user/:identifier` (`lib/features/public_profile/views/pages/profile_screen.dart`). Your own profile uses your user id as the identifier. There is no `/dashboard/profile` route. Edit uses `EditProfilePanelRoute` at `/edit-profile` (`_signedInGuard`, `app_router.dart`), built in `lib/core/widgets/popup/edit_profile_panel.dart`.

## Sub-features

- `own-profile`: tooltip `Edit profile` (pencil) and tooltip `Menu`, which opens the end drawer (`views/widgets/drawer_widget.dart`): `Share profile`, `Library` (under `Your content`), `Settings`, `Log out`.
- `other-profile`: `Follow` / `Unfollow`, `Gift a 24 h pass`, and `More options` with `Report user` and `Block user`.
- `counters`: Semantics `{n} Followers` and `{n} Following`. Following is tappable on your own profile only.
- `extras`: badge row, `Complete your profile` card (own, incomplete), `Folders` row of public folders (opens `/folder/:id`), `More links` sheet. Blocked accounts: `/blocked-accounts`.
- `edit-profile` panel: title `Edit profile`, fields `Name`, `Username`, `Bio`, buttons `Change photo`, `Remove photo`, `Change cover photo`, and `Save changes` (disabled until you change something). Back tooltip is `Back`.
- `share-profile`: drawer `Share profile` makes a link with `createUserDynamicLink`. It is not `/share-prism` (that is `Invite friends` from Rewards).

## How to get to it (user POV)

- Tap `Your profile` (the avatar) in the top app bar (`features/home-feed.md`).
- Tap a user's name or avatar in search, a wallpaper author, or a follower list.
- Own profile: tap `Edit profile`, or `Menu` then the drawer rows.
- Signed out: the page shows a sign-in prompt and a `Settings` icon only.

## Driving it with the helper

Preconditions:

- A signed-in human for own-profile edit, drawer, and guarded actions. Signed-out users only see the prompt.

- **Own profile.** Snapshot `--tag profile-own`. Assert `Edit profile` and `Menu`. Open `Menu` and assert `Share profile`, `Library`, `Settings`.
- **Other profile.** Open `More options`; assert `Report user` and `Block user`. Do not tap them on a real account; ask the human first.
- **Counters.** Tap the `Following` pill on your own profile and assert the list opens. Do the same for `Followers`.
- **Edit profile.** Assert `Name`, `Username`, `Bio`, `Change photo`, `Change cover photo`, `Save changes`. Type, then tap `Back` and discard. Saving a real account needs the human's go-ahead.
- **Share profile.** Tap `Share profile` in the drawer and assert the share sheet opens. Do not send it.
- **Proof.** Snapshot own profile, the drawer, another profile with `More options` open, and the edit panel.

## Gotchas

- `EditProfilePanel` is shared UI under `lib/core/widgets/popup/`. Its photo buttons are in `edit_profile_header.dart`.
- The panel has no `Close` tooltip. Use `Back`. Back with unsaved changes asks to discard.
- Follow, block, report, gift and save change real accounts. Prefer read-only checks.
- The drawer `Log out` is terminal. Never tap it in a recipe.
- `Bio` hint ends with a real ellipsis character, not three periods.
