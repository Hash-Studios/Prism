# Wall of the day

Each day Prism picks one wallpaper. The home feed shows it on a card. A push notification tells the user about it. The user can also see the last 30 picks in an archive.

## Where to find it

- The **wall of the day** card in the home carousel (`WallOfTheDayCard`).
- The **See past picks** button on that card. It opens the **Past picks** page (`WotdArchivePage`, route `WotdArchiveRoute`, path `/wotd-archive`).
- The daily push notification opens the wallpaper detail screen.

## Platforms and plans

- Android and iOS. The code has no platform branch.
- Free. The card, the archive and the detail screen have no coin or premium gate.
- A signed-out user on iOS can browse. Opening a wallpaper follows the normal detail screen rules.

## How it works

| Path | Role |
|---|---|
| `lib/features/wall_of_the_day/views/widgets/wall_of_the_day_card.dart` | The card and the **See past picks** button. |
| `lib/features/wall_of_the_day/views/pages/wotd_archive_page.dart` | The **Past picks** page. |
| `lib/features/wall_of_the_day/biz/bloc/wotd_archive_bloc.j.dart` | Loads the archive. Events: `started`, `refreshRequested`. |
| `lib/features/wall_of_the_day/domain/usecases/fetch_wotd_archive_usecase.dart` | Calls `WallOfTheDayRepository.fetchRecent`. |
| `lib/features/wall_of_the_day/data/repositories/wall_of_the_day_repository_impl.dart` | `fetchToday` and `fetchRecent`. |
| `functions/src/wallOfTheDay.ts` | Daily function. Picks the wall and archives the old pick. |

### The card

- The card shows the wallpaper thumbnail, the text "wall of the day", and the creator name.
- A tap on the card opens the wallpaper detail screen. The card passes the wallpaper that the repository already loaded. The detail screen does not fetch it again. If the card has no loaded wallpaper, it opens the detail screen by id as before.
- The analytics event `wotd_opened` has the source `card_tap`.
- The card decodes its image at screen width, through the shared image cache.
- **See past picks** is a text button at the bottom of the card. It is at least 48 by 48 dp. A tap opens the archive. It does not open the wallpaper.

### The archive

- The daily function writes each old pick to `past_picks/{yyyy-MM-dd}` with `wallId` (a `walls` document id) and `date`. Anyone can read `past_picks`.
- `fetchRecent` reads the 30 newest documents, ordered by `date`, newest first. The source tag is `wotd.past_picks`.
- For each document the repository loads the wall with `fetchByDocumentId`. It skips a wall that is gone, not reviewed, from a blocked creator, or has no image address.
- If every wall lookup fails, the page shows an error. If only some fail, the page shows the walls that loaded.
- The page shows a grid with one tile per pick and a date label under it, for example "Sun 4 Jan". The image has a hero animation to the detail screen. A tap opens the detail screen with the loaded wallpaper and records `wotd_opened` with the source `archive`.
- Pull down to refresh. The old picks stay on screen while the refresh runs. If the refresh fails, the old picks stay.
- States: loading skeleton, error with **Try again**, and "No past picks yet".

## Limits

- The archive holds at most 30 picks. A pick with a missing wall does not show, so the page can show fewer than 30.
- The archive does not include today's pick. The card shows today's pick.
- The daily function archives a pick when it picks the next one. A pick can appear in the archive a day after it was the pick.
- The page has no paging. It has no filter or search.
- The date label uses the device time zone. The `date` field is a UTC time.

## How to test

1. Open the home tab. Make sure the **wall of the day** card shows.
2. Tap **See past picks**. Make sure the **Past picks** page opens with date labels.
3. Tap a tile. Make sure the detail screen opens with the same wallpaper and no loading state.
4. Go back. Pull down. Make sure the list reloads.
5. Turn on airplane mode and open the page on a fresh start. Make sure the error state and **Try again** show.
6. Tap the card (not the button). Make sure the detail screen opens.

Automated tests:

- `test/features/wall_of_the_day/wall_of_the_day_card_test.dart`
- `test/features/wall_of_the_day/wotd_archive_page_test.dart`
- `test/features/wall_of_the_day/biz/bloc/wotd_archive_bloc_test.dart`
- `test/features/wall_of_the_day/data/repositories/wall_of_the_day_repository_impl_test.dart`

Command:

```sh
fvm flutter test --no-pub test/features/wall_of_the_day
```
