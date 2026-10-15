# Profile

Every creator has a public profile with a name, a username, a photo, a bio, links, a follower count and a wallpaper grid. A user can follow a creator, share a profile link, and report or block a creator.

## Where to find it

- The **Profile** tab shows the user's own profile (`ProfileScreen`, `lib/features/public_profile/views/pages/profile_screen.dart`).
- A tap on a creator in the Followers or Following list, or a profile link, opens that creator's profile.
- **Edit Profile** opens `EditProfilePanel` (`lib/core/widgets/popup/edit_profile_panel.dart`).
- The **Followers** and **Following** counts open the lists (`UserRelationListBody`).
- The profile drawer has **Share your Profile**. **Settings** has a share item too.
- The three-dot menu on another creator's profile has **Report** and **Block**. A blocked creator shows the blocked-user shell instead of the profile.

## Platforms and plans

Android and iOS. Profiles are free. A signed out user can view a profile but cannot follow, report or block.

## How it works

| Path | Role |
|---|---|
| `lib/features/public_profile/data/repositories/public_profile_repository_impl.dart` | Reads the profile, the walls, the lists. Follows and unfollows. |
| `lib/features/public_profile/biz/bloc/public_profile_bloc.j.dart` | Follow state, roll back, posts topic, analytics. |
| `lib/features/public_profile/domain/creator_label.dart` | `creatorLabel`: the text to show for a creator. |
| `lib/core/constants/profile_links.dart` | The link types, `sanitizeProfileLink`, `safeProfileLinkUri`, `minUsernameLength`. |
| `lib/core/widgets/popup/edit_profile_panel.dart` | The edit form with inline errors. |
| `lib/data/share/create_dynamic_link.dart` | `createUserDynamicLink` and `createSharingPrismLink`. |
| `lib/features/session/views/pages/share_prism_screen.dart` | The invite screen. |

### Names

The app never shows an email address as a name. `creatorLabel` uses, in order: the name, the username, then **Prism creator**. A name that looks like an email address is skipped. This applies to the profile header, the follower and following rows, the follow message and the block dialog.

### Username

- A username has 3 characters or more. It has letters, digits and underscores only. Before this change the minimum was 8.
- While the user types, the field shows an inline error: "Use at least 3 characters.", "Use letters, numbers and underscores only.", or "That username is taken."
- A small spinner and a check or cross show the result of the availability check. **Update** stays off until the name is free.
- The check queries `usersv2` on `username` and `usernameLower`. It runs in the app, so two users can still pick the same free name at the same moment. The server callable `claimUsername` exists but the app does not call it yet.

### Links

- A link type has a rule. For example a GitHub link must hold `github`.
- The app keeps only `https`, `http` and `mailto` links, and each needs a host. A bare domain gets `https://`. The email type stores the bare address, so builds that shipped before this change can still open it.
- A wrong value shows an inline error ("Enter a valid link.", "Enter a valid email address.", or "Enter a valid github link."). **Update** stays off until the field is valid or empty. Before this change the app dropped the value without a message.
- A tap on a link icon opens it with `launchUrl`. If the link has an unsafe scheme or fails to open, the app shows the message "Couldn't open this link.". It does not crash.
- Any email provider works for the email type. Before this change only `@gmail.com` opened as mail.

### Follow and unfollow

- A follow changes two documents: `following` on the user and `followers` on the creator. The app now writes both in one Firestore transaction (`public_profile.follow`, `public_profile.unfollow`). If one write fails, neither is saved.
- The button changes at once. If the transaction fails, the bloc puts the button back and shows the failure message.
- After a follow, the app subscribes to the creator posts topics. It passes the creator `uid`, so the topic `posts_<uid>` needs no extra read.
- The event `follow_result` has `action` (`follow` or `unfollow`) and `result` (`success` or `failure`).

### Share links

- **Share your Profile** builds `https://prismwalls.com/user/<username>`. The link never holds an email address. The preview title is `<name> (@username)`, and a name that looks like an email is replaced by the username.
- If the username is empty, the app shows "Set a username to share your profile" and opens **Edit Profile**. It does not make a link.
- If the link cannot be made, the function throws. The caller shows "Couldn't create the link. Try again."
- **Share Prism** (`SharePrismScreen`) makes the invite link. The button shows **Creating link…** while it works. If it fails, the screen shows "Couldn't create the link." and **Try again**. A signed in user never sees a "Sign in" message. A signed out user does.
- The invite preview reads "<Name> invited you to Prism" and shows the profile photo. Without a usable name it reads "Join Prism".

## Limits

- The profile still keys follows and lookups by email. The email also stays on each approved wall. A later server change must add a `uid` field and remove the email. Until then, the email is readable in the wall record.
- The drawer item and the Settings item call `createUserDynamicLink`. It throws when the link fails. Each caller must catch the error and show "Couldn't create the link. Try again." Settings does. The drawer does not yet.
- The `claimUsername` callable is not used yet (see Username).

## How to test

1. Open **Edit Profile**. Type `ab` in Username. Check the inline error and that **Update** is off. Type `abc`. Check that the error goes away if the name is free.
2. In the link field, type `javascript:alert(1)`. Check the error. Type `https://example.com`. Check the error goes away.
3. Add an email link with a non-Gmail address. Tap its icon on the profile. Check that the mail app opens.
4. Follow a creator. Turn on airplane mode before you tap, then tap. Check that the button goes back and the failure message shows.
5. Clear your username in a test account, then tap **Share your Profile**. Check the message and the edit panel.
6. Open Share Prism with no network. Check the retry state. Turn the network on and tap **Try again**.
7. Run `fvm flutter test test/core/constants test/core/widgets/popup/edit_profile_panel_test.dart test/features/public_profile test/features/session/share_prism_screen_test.dart test/data/share`.
