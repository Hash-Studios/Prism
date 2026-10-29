# Wall requests

A user asks for a wall in a short text, for example "dark minimal mountains". Other users upvote the request. Creators and Prism Studio fill the top requests. When a wall fills a request, the requester and the voters get a push. The votes also tell Studio what to make next.

## Where to find it

- **Search.** When a search has no results, the empty state shows "Can't find it?" and "Request it". The sheet opens with the search query in the text field. When a search has 1 to 5 results, a short prompt shows below the results.
- **Discover.** The row "Wall requests" in the group under the search field opens the requests page (`/requests`).
- **Upload.** The upload form has the row "Fills a request". The creator can pick an open request that the wall answers.

## Platforms

Android and iOS. The same code runs on both.

## Free and Pro

Free. A guest can read the requests page. A user must sign in to make a request or to vote.

## How it works

### Requests page

The page has 3 tabs:

| Tab | Shows |
|---|---|
| Top | Open requests from the last 30 days, most votes first. |
| New | Open requests, newest first. |
| Filled | Filled requests, newest fill first. Each row shows the wall that filled it. A tap on the wall opens it. |

Each row shows the text, the tags, the vote count and the age. The user's own request shows "Your request" and has no vote button. The row menu has "Report request". Admins also see "Hide request" or "Show request", and hidden requests show the label "Hidden".

A vote changes the row at once. If the server refuses the vote, the row goes back and a toast shows the reason.

### Make a request

1. The user writes 3 to 80 characters and picks up to 3 tags. Tags come from the browse categories and the moods Dreamy, Dark and quiet, and Bright and bold. No image upload is possible.
2. The app calls `createWallRequest`.
3. If a close open request exists, the sheet shows it with "Upvote this instead". If the words are not the same, the sheet also shows "Request mine anyway". If the close request is the user's own request, the sheet says "You asked for this already".
4. Otherwise the server makes the request and the sheet closes with a toast.

### Close requests

The server lowercases the text, removes accents and punctuation, and removes filler words such as "wallpaper", "please" and "hd". The remaining words, sorted, are the request tokens. Two requests are close when their token sets overlap by 0.6 or more (Jaccard). The same tokens are an exact match. For an exact match the server never makes a second request.

### Fill a request

| Who | How |
|---|---|
| Creator | The creator picks the request in the upload form. The wall doc gets `requestId`. When an admin approves the wall, `onWallApproved` fills the request. |
| Prism Studio | The daily run (`planStudioBatch`) takes up to 3 open requests and makes Studio candidates from them. These candidates count against the daily limit (`maxCandidatesPerDay`). An admin reviews each result. When an admin approves the wall, `onWallApproved` fills the request. |

A Studio request must be visible, have at least 3 votes, be from the last 30 days, still pass the text checks, and not be given to Studio in the last 7 days. The prompt is the request text plus the normal Studio composition rules. The first category tag is the wall category. Aesthetic becomes Abstract, Forest becomes Nature and AMOLED becomes Dark. A request without a category tag gets General.

A fill is done once. If a second wall names the same request, the request keeps the first wall. A creator wall does not fill a request when the creator and the requester block each other.

### Filled push

When the filled wall has its protected original, the requester and every voter get one push: "Your request is here" and the request text. The push opens the gallery page with the filled wall first and up to 3 walls like it.

| Rule | Detail |
|---|---|
| Once per request | `notifiedAt` on the request is set in a transaction before the sends. A retried event sends nothing. |
| Daily cap | A user gets at most 1 request push a UTC day (`usersv2/{uid}/private/wallRequestPush`). A second fill that day writes only the inbox entry. |
| Gallery image | The push has a single image. The Wall of the Day push is the one gallery image of the day. |
| Opt-out | The Posts switch. With Posts off, the user gets only the inbox entry. |
| Blocks | A user who blocks, or is blocked by, the requester or the creator gets nothing. |

## Data

`wallRequests/{requestId}`:

| Field | Meaning |
|---|---|
| `text` | The public text, trimmed, spaces collapsed. |
| `key`, `tokens` | The request tokens, used to find close requests. |
| `tags` | Up to 3 category names or mood ids. |
| `requesterUid` | The requester. The app never gets it. It gets only `requesterName` and `requesterPhoto`. |
| `status` | `open` or `filled`. |
| `hidden` | True when an admin or 3 trusted reports hid the request. |
| `voteCount` | Kept by the vote transaction. |
| `filledWallId`, `filledWallThumb`, `filledBy`, `fillerUid`, `fillerName`, `filledAt` | Set by the fill. |
| `studioRunId`, `studioQueuedAt` | Set when a Studio run took the request. |
| `notifiedAt` | Set when the filled push starts. |

`wallRequests/{requestId}/votes/{uid}` holds `uid` and `createdAt`. One doc for each voter.

## Callables

All callables run in `asia-south1` and `us-central1`.

| Callable | Input | Rules |
|---|---|---|
| `createWallRequest` | `text`, `tags`, `force` | Sign-in. An open account. Text checks. At most 3 requests a UTC day. |
| `setWallRequestVote` | `requestId`, `vote` | Sign-in. Not your own request, not hidden, not filled, no block in either direction. At most 200 vote changes a UTC day. The same value twice is a no-op. |
| `listWallRequests` | `tab` | Guests too. Hidden requests show only to admins. Requests of users that the viewer blocked, or that blocked the viewer, do not show. |
| `setWallRequestHidden` | `requestId`, `hidden` | Admins only. |

### Text checks

`publicRequestText` in `functions/src/wallRequests.ts` refuses text that:

- has fewer than 3 or more than 80 characters after trimming;
- has control, format, private-use or unassigned characters (these can hide or reorder text);
- has a word from a short list of slurs and sexual words, also with digits for letters ("p0rn") and repeated letters;
- has only filler words.

The list is short. Reports and admin hiding catch the rest.

### Votes

Votes go through `setWallRequestVote`, not through client writes. The callable reads the request, the vote doc and both block docs, then writes the vote doc and `voteCount` in one transaction. Firestore runs transactions on the same request one at a time, so the count stays equal to the vote docs. A callable also lets the server check blocks and a daily limit, which a rule cannot do.

## Safety

- **Report.** "Report request" uses the existing report flow with the content type `wallRequest`. When 3 reporters with accounts older than 7 days report a request, `onContentReportCreated` hides it.
- **Hide.** Admins hide or show a request from the row menu. A hidden request leaves every list, Studio and the filled push.
- **Blocks.** Hidden in both directions in lists, close-request matches, votes, fills and pushes.
- **Public data.** Only the display name and the avatar.
- **Account deletion.** `deleteAccount` deletes the user's requests with their votes, removes the user's votes from other requests with a lower `voteCount`, and deletes the rate docs.

## Firestore rules

Clients cannot write `wallRequests`, its `votes`, `wallRequestRateDaily` or `wallRequestVoteRateDaily`. A request doc holds uids, so only its requester and admins can read it directly. Everyone else reads requests through `listWallRequests`, which returns only the display name and the avatar and applies the block and hidden filters. A vote doc is readable only by its voter.

## Analytics

| Event | When |
|---|---|
| `wall_request_sheet_opened` | The sheet opens. `source`: `search` or `requests_page`. |
| `wall_request_created` | A request is made. `source`, `tag_count`, `forced`. |
| `wall_request_duplicate_upvoted` | The user upvotes the close request instead. `exact`. |
| `wall_request_vote_toggled` | A vote change succeeds. `voted`, `tab`. |
| `wall_request_filled` | An admin approves a wall that has a `requestId`. `filled_by`: `creator` or `studio`. |
| `wall_request_push_opened` | The user opens the filled push. `request_id`. |

## Main files

| Path | Role |
|---|---|
| `functions/src/wallRequests.ts` | Callables, text checks, close-request match, fill, filled push, Studio picks, account clean-up. |
| `functions/src/studio/planRun.ts`, `functions/src/studio/plan.ts` | Studio candidates from requests. |
| `functions/src/onWallApproved.ts` | Fill and push on approval. |
| `lib/features/wall_requests/` | Entity, repository, cubits, page, sheet, picker. |
| `lib/features/user_search/views/pages/search_screen.dart` | Search entry point. |
| `lib/features/wallpaper_upload/views/widgets/fills_request_row.dart` | Upload entry point. |

## Deploy order

1. Firestore indexes (`firestore.indexes.json`: 7 `wallRequests` indexes and the `votes.uid` collection group index). Wait until they are built.
2. Firestore rules.
3. Cloud Functions: run `make functions-env` first. Then deploy `createWallRequest`, `setWallRequestVote`, `listWallRequests`, `setWallRequestHidden` (new), and `onWallApproved`, `planStudioBatch`, `runStudioBatch`, `processStudioCandidate`, `deleteAccount`, `submitContentReport`, `onContentReportCreated` (changed).
4. Client release.

If the client ships first, the requests page shows the error state, and requests cannot be made.

## Limits

- The text checks use a short word list. Offensive text in other words or languages stays until a report or an admin hides it.
- Top reads the 200 most voted open requests and keeps the last 30 days. If more than 200 old requests have more votes, Top can show fewer rows.
- Each tab shows at most 50 requests. There is no paging.
- The filled push reads all protected walls once to find similar walls. This is the same read as the Wall of the Day pick.
- A failed push still uses the user's daily request push.
- Admins see the request id on a wall, not the request text, in the review screens.
- Desktop, Gaming and Pastel categories are not part of this feature. See issue #574.

## How to test

```sh
cd functions && npm run build && node --test lib/__tests__/wallRequests.test.js lib/__tests__/wallRequestsStudio.test.js
make rules-test
fvm flutter test test/features/wall_requests
```

On a device:

1. Sign in with account A. Search for a word with no results. Tap "Request it" and send the request.
2. Sign in with account B. Open Discover, then "Wall requests". Upvote the request.
3. With account B, request the same words. The sheet offers "Upvote this instead".
4. Upload a wall as a creator and pick the request in "Fills a request".
5. Approve the wall in the admin review.
6. Accounts A and B get the push. The request shows in the Filled tab with the wall.
