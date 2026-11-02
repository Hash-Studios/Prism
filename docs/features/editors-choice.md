# Editors' Choice

Admins pick approved walls for Editors' Choice. The picks show in a row on Home, on a See all page, and as a label on the wall. The creator gets one inbox item and one push for each wall, the first time it is picked.

## Where to find it

| Surface | What the user sees |
|---|---|
| Admin review, pending wall | **Approve and pick** on a pending wall card. It approves the wall, then picks it. |
| Wall detail, admin | **Add to Editors' Choice**, or **Remove from Editors' Choice**. Admins see it on approved walls only. |
| Home (For you) | The **Editors' Choice** row. It sits after grid row 6, between the two mood rows and the creators row. |
| Row header | The title and a **See all** action. |
| See all page | The route is `/editors-choice`. The screen is `EditorsChoiceScreen`. Newest pick first, up to 60 walls. |
| Wall detail info panel | A small **Editors' Choice** label on a picked wall. |
| Inbox | "Your wallpaper is an Editors' Choice" for the creator. |

## Platforms and plans

Android and iOS. Every plan sees the row and the page. No coin, premium or Pro gate applies.

## How it works

### Admin pick

1. An admin taps **Approve and pick** or **Add to Editors' Choice**.
2. The app calls `setEditorsChoice` with `{wallId, picked, requestId}`.
3. The callable checks the caller with `isAdminCaller`. A non-admin is refused.
4. The callable checks the wall with `readyWall` from `functions/src/wallEligibility.ts`.
5. The callable writes the wall fields in one transaction.

A pick passes `readyWall` only when all of these are true:

- The wall is approved.
- The original is protected, and it has a ready delivery.
- The wall is not streak exclusive.
- The wall is not reserved for a Drop.
- The wall is not in a premium collection.

If the original is not ready yet, **Approve and pick** approves the wall only. It shows a message to pick the wall later from the wall page.

### Fields on a pick

| Field | Value |
|---|---|
| `walls.editorsChoiceAt` | Server timestamp. It is kept when the wall is picked again. |
| `walls.editorsChoiceBy` | The admin uid. The app never stores an email here, because walls are public. |

Clear deletes both fields.

### Retries

- Each call has a `requestId`. The callable stores it in `editorsChoiceRequests/{requestId}`.
- A retry with the same `requestId` replays the first result. It does not change the wall again.
- The same `requestId` for a different change is refused with `already-exists`.

### Creator notice

- The creator gets one inbox item and one push for each wall. This happens the first time the wall is picked.
- The claim doc is `editorsChoiceNotices/{wallId}`.
- Pick, clear and pick again send nothing new.
- The push respects `postAlerts` in `usersv2/{uid}/private/session`. A false value skips the push and the inbox item.
- Studio walls get no push.
- The inbox doc id is `editors_choice_<wallId>`. The kind is `editorsChoicePicked`. The route is `wall`.
- The push has the `notification_kind` `editors_choice`.
- The notice has no native localization keys, like `wallRemixed`. The inbox copy is localized in `lib/features/in_app_notifications/domain/notification_copy.dart`.

### Home row

- The row uses the mood row pattern. See [home-feed.md](home-feed.md).
- The row hides while it loads.
- The row hides on an error.
- The row hides when there are fewer than 4 picks.
- The client query reads `walls` where `review == true`, ordered by `editorsChoiceAt` descending.
- The client then applies the free-wall filter in `lib/core/wallpaper/free_wall_eligibility.dart`.
- The client then applies the viewer's block, AI and anime filters.
- Feed cells stay image only. They show no Editors' Choice label.

## Data

| Path or field | Writer | Readers | Contents |
|---|---|---|---|
| `walls.editorsChoiceAt` | Server only | Public, through wall reads | Server timestamp of the pick. |
| `walls.editorsChoiceBy` | Server only | Public, through wall reads | Admin uid. |
| `editorsChoiceRequests/{requestId}` | Server only | Nobody | Stored result of a call. |
| `editorsChoiceNotices/{wallId}` | Server only | Nobody | Marks the creator notice as sent. |

Firestore rules refuse client writes of `editorsChoiceAt`, `editorsChoiceBy` and `byStudio`. These fields are in `wallServerKeysAbsent` and `wallServerKeysUntouched`. The two collections have no client access.

Index: `walls` with `review` ascending and `editorsChoiceAt` descending.

## Deploy order

Do these steps in this order. Do not deploy from this doc.

1. Rules: `firebase deploy --only firestore:rules --project prism-wallpapers`.
2. Indexes: `firebase deploy --only firestore:indexes --project prism-wallpapers`. Wait until the `walls` index for `review` and `editorsChoiceAt` is `READY`.
3. Functions: `setEditorsChoice`, `onWallApproved` and `projectUserProfile`.
4. Run the `byStudio` backfill dry run. Run it with `--apply` only with the owner's OK. See [wall-credits.md](wall-credits.md).
5. Ship the app.

Use [backend-deploy.md](backend-deploy.md) for the commands.

## Analytics

| Event | Fields |
|---|---|
| `editors_choice_row_seen` | `pick_count` |
| `editors_choice_opened` | `source`: `row` or `link` |
| `editors_choice_pick_changed` | `picked`, `surface`: `review` or `detail` |

## Limits

- The row needs 4 picks to show. Before that, Home shows no row.
- The row reads picks from `walls` only. A wall that leaves review drops out of the row.
- Feed cells do not show the label.

## How to test

1. As an admin, open a pending wall in admin review. Tap **Approve and pick**. Check that the wall is approved and picked.
2. Open the same wall as a user. Check the **Editors' Choice** label in the info panel.
3. Open Home with 4 or more picks. Check the row after grid row 6.
4. Tap **See all**. Check that the newest pick is first.
5. As an admin, remove the pick from the wall detail page. Check that the label and the row update.
6. Pick the same wall again. Check that the creator gets no second inbox item and no second push.
7. Run `cd functions && npm run build && node --test lib/__tests__/editorsChoice.test.js`.
8. Run `fvm flutter test test/features/wallpaper_detail/views/editors_choice_label_test.dart test/features/in_app_notifications`.
