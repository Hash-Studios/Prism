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

The "Followed by" line and the More like offer are covered in [creator-directory.md](creator-directory.md).

### Followers and Following lists

The lists read the uid edges `profiles/{uid}/followers` and `profiles/{uid}/following`. Before #541, each list stopped at the newest 500 edges.

- A page is 30 edges, newest first. The query orders by `createdAt`, then by the document id. The next page starts after the `createdAt` and id of the last edge. So a page boundary does not repeat or skip an edge, also when two edges have the same `createdAt`.
- `fetchRelationPage` gives the users of one page and the cursor of the next page. The cursor is null on the last page.
- When the last row comes near the screen, the list loads the next page. A small loading row shows at the end while it loads.
- If a next page fails, the rows stay. An error row with **Try again** shows at the end. If the first page fails, the screen shows an error state with **Try again**.
- Pull down to refresh. A refresh loads the first page again. A page that was loading when the refresh started is dropped.
- The list does not show users that the viewer blocked. The cursor counts edges, not visible users. So a page can have fewer than 30 rows. If the block list cannot load, the page fails and shows **Try again**.
- The **Followers** and **Following** counts on the profile come from `followerCount` and `followingCount` on `profiles/{uid}`. They do not come from the list length.
- Search looks at the newest 500 edges (`fetchRelationIds`) and the pages that are loaded. It also hides blocked users.
- Analytics: `relation_list_page_loaded` with `kind` (`followers` or `following`) and `page_index` (0 for the first page).
- The query needs only the automatic single-field index on `createdAt`. No index or rule change.

### Share links

- **Share your Profile** builds `https://prismwalls.com/user/<username>`. The link never holds an email address. The preview title is `<name> (@username)`, and a name that looks like an email is replaced by the username.
- If the username is empty, the app shows "Set a username to share your profile" and opens **Edit Profile**. It does not make a link.
- If the link cannot be made, the function throws. The caller shows "Couldn't create the link. Try again."
- **Share Prism** (`SharePrismScreen`) makes the invite link. The button shows **Creating link…** while it works. If it fails, the screen shows "Couldn't create the link." and **Try again**. A signed in user never sees a "Sign in" message. A signed out user does.
- The invite preview reads "<Name> invited you to Prism" and shows the profile photo. Without a usable name it reads "Join Prism".

## Pro badge

A Prism Pro member shows a Pro badge on the public profile. The badge sits above the earned badges. Its screen reader label is "Prism Pro member".

- `profiles/{uid}.proBadge` is true only when `usersv2.premium` is true and `usersv2.showProBadge` is not false.
- `functions/src/profiles.ts` writes `proBadge` in `projectedProfile`.
- `projectUserProfile` runs it on every `usersv2` write. So `syncSubscription` and the daily `reconcileSubscriptions` (02:30 UTC) update the badge. Gifted and promo Pro passes live in `private/economy` and do not set `premium`, so they do not show the badge.
- An expiry removes the badge at the next successful sync or reconcile. A RevenueCat error delays the removal until the next run.
- An expiry or an opt-out removes the badge.
- `syncSubscription` does not write `profiles` directly. The projection rewrites the whole profile doc. A direct write could remove a field that another writer adds.
- Clients cannot write `profiles`.

### Opt out

- Settings shows **Show Pro badge on my profile** to premium users only. The switch is on by default.
- The switch writes `usersv2.showProBadge`. Firestore rules allow only a bool.
- The change reaches the public profile through `projectUserProfile`.
- Analytics: `pro_badge_toggled` with `shown`.

## Header layout

- The header photo has a 4 point accent ring (`cs.primary`) when no frame is equipped. The ring is painted in front of the photo. The photo goes to the middle of the ring, so no other colour shows between the ring and the photo (#558). The visible photo is 78 points across.
- The counts row shows **Following**, **Followers** and, on another creator's profile, the rank. A short divider is between each item. If the row does not fit, for example with large text on a narrow phone, the items stack in a centred column with no dividers. Words that fit the available width do not break across lines (#548). A single word wider than the available width still wraps.

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
7. Set the text size to the largest value on a 360 point phone. Open another creator's profile. Check that each count and label shows full words.
8. Open the Followers list of a creator with more than 30 followers. Scroll to the end. Check that more rows load, that no row shows twice, and that the loading row goes away at the end.
9. Run `fvm flutter test test/core/constants test/core/widgets/popup/edit_profile_panel_test.dart test/features/public_profile test/features/session/share_prism_screen_test.dart test/data/share`.
