# Categories and wallpaper tiles

The Collections tab lists collections and categories. A category shows a grid of wallpapers. Every wallpaper tile in the app has a long-press menu.

## Where to find it

- The **Collections** tab. Category tiles show after the collection tiles.
- The "Browse by Category" row on the Search tab opens the same category screen.
- Route: `CollectionViewRoute` with `collectionName: 'category:<name>'`.

## Platforms and plans

- Android and iOS.
- Free. Collections can be premium. Categories are never premium.
- **Set as wallpaper** in the long-press menu shows on Android only.

## How it works

| Path | Role |
|---|---|
| `lib/data/categories/categories.dart` | The 24 built-in category tiles. |
| `lib/data/categories/category_catalog.dart` | `CategoryCatalog.current`: the Remote Config list, else the built-in tiles. |
| `lib/data/categories/category_definition.dart` | `CategoryDefinition` and `hasPrismWalls`. |
| `lib/features/category_feed/data/repositories/category_feed_repository_impl.dart` | Loads a category page. Puts Prism walls first. |
| `lib/features/prism_feed/data/repositories/prism_wallpaper_repository_impl.dart` | `fetchByCategory`. |
| `lib/features/category_feed/biz/bloc/category_feed_bloc.j.dart` | Category state. |
| `lib/features/category_feed/views/pages/collection_view_screen.dart` | The screen. |
| `lib/features/category_feed/views/widgets/source_feed_grid.dart` | The grid. |
| `lib/features/category_feed/views/widgets/wallpaper_tile.dart` | One tile. |
| `lib/features/category_feed/views/widgets/wallpaper_quick_actions.dart` | The long-press sheet. |

### Remote category list

- The Remote Config key `categories_v1` can replace the built-in list. Then a new category needs no app update.
- The value is a JSON array in display order:

  ```json
  [{"name": "Diwali", "source": "pexels", "imageUrl": "https://...", "secondaryImageUrl": "https://..."}]
  ```

- `source` is `pexels` or `wallhaven`. The name is also the search query. `secondaryImageUrl` is optional. The search row shows it when the first picture fails to load.
- The app skips an entry without a name or `imageUrl`, an entry with another source, and a second entry with the same name. If no entry is left, or the key is empty, the app shows the built-in list.
- The value replaces the full list. To add one category, copy the built-in list, add the entry, and publish. To go back, delete the key or set it to an empty string.
- The Collections tab, the search "Browse by Category" row and the quick tile picker use the list. The upload category picker and the quick tile default stay on the built-in list. The upload picker lists the names that the server classifier writes.
- The first read with Remote Config ready stays for the session. A value that the app fetches later shows on the next launch. Release builds fetch at app start, at most once an hour. A user sees a change after one or two cold starts.
- A category name the app does not translate shows as it is, in all languages.

### Prism walls first

- 20 category names match the names that the upload classifier writes to `walls.category`: Nature, Architecture, Cars, Anime, Gaming, Space, Ocean, Flowers, Neon, Dark, Abstract, 3D Render, Minimal, Gradient, AI Art, Cyberpunk, Vintage, Landscape, Galaxy and Pastel. `CategoryDefinition.hasPrismWalls` is true for them. Aesthetic and Forest are not on the list.
- Page 1 of such a category first asks Firestore for up to 24 reviewed Prism walls with that category, newest first (`PrismWallpaperRepository.fetchByCategory`). The source tag is `category_feed.prism_first`. The query uses the index on `category`, `review` and `createdAt`.
- The repository puts those walls before the Wallhaven or Pexels walls. It removes a wall that is in both lists. It compares the full image address in lowercase.
- Page 2 and later come from Wallhaven or Pexels only.
- A creator that the user blocked never shows.
- If the Prism query fails, the page shows the provider walls and writes a warning to the log. A category with no Prism walls shows the provider walls only.
- The saved copy of the page (the offline fallback) includes the Prism walls.
- The grid shows Prism and provider tiles together. Analytics use the source context `category_prism_first` for a Prism tile in a provider category.

### Follow a category

A signed-in user can follow a category. The 20 classifier names in **Prism walls first** can be followed. The seven Home moods can be followed too. The push is described in [Topic digest](notifications.md#topic-digest).

Stock-only categories (AMOLED, Aesthetic and Forest) and Desktop have no Follow button. No new Prism walls land there through approval.

The **Follow** button is in the header of each category page and each mood page. A guest who taps it sees the sign-in prompt.

A user can follow up to 20 topics, across categories and moods. At 20, the app shows "You can follow up to 20 topics. Unfollow one in Settings first." To unfollow, open **Settings**, then **Topics you follow**, and tap **Unfollow**.

A followed topic can send one push a day at 16:00 local time. The push comes only when the topic got new walls in the last 24 hours. It can show a gallery of those walls.

The **Following** row sits at the top of **For you**, above the mood chips. It lists the followed topics. A dot marks a topic with a wall newer than the last time the user opened its page on this device. Opening the page clears the dot. To hide the row, turn off **Show topics you follow** in the Home section of the layout settings.

### AMOLED tile

- A new tile, **AMOLED**, searches Wallhaven for "amoled". Its picture is a dark Pexels photo.
- It has no Prism walls, because the classifier has no AMOLED category.

### Pastel, Gaming and Desktop (#574)

Users asked for Pastel, Gaming, Blender-style 3D and Desktop walls. Three tiles are new: **Pastel**, **Gaming** and **Desktop**. Blender-style 3D did not get a new tile, because **3D Render** already exists. It got a better search term and a new cover.

#### What a category page shows

- A Pexels or Wallhaven category shows Prism walls first, then stock walls. Prism walls come first only on page 1, and only when the category name is a classifier name. Page 2 and later are stock walls.
- Pastel and Gaming are classifier names now. Thus their pages can show Prism walls first.
- **Desktop** shows Prism walls only. Each wall on it has a desktop version (`walls.desktopVariant`).

#### Search terms

A tile can have a search term that is not its name (`CategoryDefinition.query`). The name stays the data key, the analytics value and the cache key. The Remote Config list accepts an optional `query` field.

| Tile | Source | Search term | Cover (Pexels photo) |
|---|---|---|---|
| Pastel | Pexels | `pastel aesthetic` | 7354509, then 2088142 |
| Gaming | Pexels | `gaming wallpaper` | 33888375, then 30353203 |
| 3D Render | Pexels | `3d render abstract` (was `3D Render`) | 31687154, then 29101883 |
| Desktop | Prism | Walls with a desktop version | The "Rose Arch · Sunrise" desktop preview, then "Pier Cabin · Noon" |

Each cover comes from the first 20 results of its own search. The Pexels covers ship in `assets/images/covers/`. The Desktop cover loads from `img.prismwalls.com`.

#### How the search terms were picked

On 2026-11-03 we counted the results with the same filters that the app sends: portrait only, and for Wallhaven `categories=100` and `purity=100`. Pexels stops its count at 8,000. Then we looked at the first 20 results of each search. "Good" means a usable phone wallpaper on the topic.

| Search | Results | Good of 20 | Result |
|---|---|---|---|
| Pexels `Pastel` | 8,000+ | 3 | Dropped. Most results are pastel pastries (food). |
| Pexels `pastel wallpaper` | 8,000+ | 20 | Dropped. Almost all are soft gradients, so it repeats Gradient. |
| Pexels `pastel aesthetic` | 8,000+ | 19 | **Picked for Pastel.** |
| Wallhaven `pastel` | 8 | n/a | Dropped. Too few walls. |
| Pexels `Gaming` | 8,000+ | 4 | Dropped. Mostly people who hold controllers. |
| Pexels `gaming wallpaper` | 8,000+ | 16 | **Picked for Gaming.** Controllers, setups and neon rooms. |
| Pexels `retro gaming` | 8,000+ | 14 | Not picked. Good, but only old consoles. |
| Wallhaven `video games` (newest first) | 2,084 | 6 | Dropped. One fan-art series repeats. Many crops show bodies only. |
| Wallhaven `video games` (toplist) | 164 | 2 | Dropped. Mostly fan service. |
| Wallhaven `video game landscape` | 49 | 15 | Dropped. Good, but too few walls for a feed. |
| Pexels `3D Render` (old term) | 3,568 | 11 | Replaced. Half are dim room interiors. |
| Pexels `3d render abstract` | 8,000+ | 20 | **Picked for 3D Render.** Blender-style shapes. |
| Pexels `blender 3d` | 3,786 | 13 | Dropped. Room interiors again. |
| Wallhaven `3D` | 1,307 | 5 | Dropped. Game screenshots and fan service. |

Wallhaven sorts by newest first in the app, so its first 20 change every day. Pexels results are more stable.

#### Prism walls that match today

On 2026-11-03 we read the 2,559 approved walls with a read-only query. Of these, 2,358 have Vision labels.

| Tile | Prism walls with that category now | After the backfill | Notes |
|---|---|---|---|
| Pastel | 0 | 0 | Vision never gave the label "Pastel". 8 walls have the tag `pastel`, but their creators picked another category. |
| Gaming | 0 | 4 | 2 come from Anime, 2 from General. |
| 3D Render | 1 | 1 | |
| Desktop | 6 | 6 | The desktop backfill has 129 more eligible walls. See [desktop-companions.md](desktop-companions.md). |

Thus Pastel and Gaming pages are full on day one from Pexels. Prism walls join them when new uploads get these labels.

#### Desktop tile

- `CategorySearchType.desktop` marks the tile. `PrismWallpaperRepository.fetchDesktopCompanions` reads approved walls with `desktopVariant.v > ''`, 24 per page, in `desktopVariant.v` order. The source tag is `category_feed.desktop`.
- The query needs the index `walls (review ASC, desktopVariant.v ASC)`. It is in `firestore.indexes.json`. Deploy it before the release that ships this tile.
- The order is stable but not newest first. Firestore must sort by the field of the `>` filter first.
- On the Desktop page, the detail screen opens with `desktopDownload: true`, including after a swipe to another wall. **Download** then saves the 2560 x 1600 desktop file through `resolveOriginalAccess` with variant `desktop`. It has its own grant, its own name in Downloads (`<phone name>_desktop-<v>.png`) and the same price as the phone file. A wall without a desktop version uses its phone file. **Set** still sets the phone wall.
- The search "Browse by Category" row and the quick tile picker do not show Desktop. The quick tile searches Wallhaven by name, so it cannot use a Prism-only tile.
- A user cannot pick Desktop as an upload category.

#### Thin categories are hidden

A category page with fewer than 12 walls (`minimumCategoryWalls`) is not listed. Today this affects only Desktop, because its walls come from Prism only. `getCategories` asks for page 1 of the Desktop walls and applies the user's AI and anime filters before the count. If the page has fewer than 12 visible walls, or the query fails or takes more than 3 seconds, the Collections tab does not show the tile. The short limit keeps the other tiles from waiting.

The check runs when the Collections tab first loads the category list. A change in the number of desktop walls shows at the next app start.

With 6 desktop walls today, **the Desktop tile stays hidden** until the desktop backfill runs. Pexels and Wallhaven categories are not counted at run time. Their counts are in the table above.

#### Classifier labels

`functions/src/wallCategory.ts` maps the Vision labels of a wall to one category (`mapLabelsToCategory`). Vision gives the labels in score order, best first. The rule list is `CATEGORY_RULES`.

The rule (#538): the most specific tier that a label matches wins. In that tier, the label with the best rank picks the category. If one label matches two rules, the rule that comes first in the list wins.

Each rule has one of three tiers:

| Tier | What it names | Examples |
|---|---|---|
| Subject | What the wall shows | `anime`, `petal`, `mountain`, `tower`, `car`, `video game`, `moon`, `coral`, `neon`, `desert`, `milky way` |
| Style | A look, a mood or a backdrop that many walls share | `sky`, `cloud`, `flower`, `plant`, `leaf`, `home`, `modern`, `light`, `night`, `art`, `old`, `star`, `horizon`, `character`, `illustration`, `cartoon` |
| Last | Pastel only | `pastel` |

A style label is used only when no label matches a subject. Pastel is used only when no other rule matches.

Examples:

| Labels, best first | Category | Why |
|---|---|---|
| Anime girl, Sky | Anime | `sky` is a style word. |
| Sky, Anime girl | Anime | The same. A backdrop never beats a subject. |
| Sports car, Sky | Cars | Before #538, this gave Nature, because the Nature rule came first. |
| Mountain, Sports car | Nature | Both are subjects. Mountain has the better rank. |
| Leaf, Green, Petal | Flowers | `leaf` is a style word. `petal` is a subject. |
| Red, Art, Modern art | Abstract | Only style words. Art has the better rank. Before #538, `modern` gave Architecture. |
| Black and white | Dark | One label matches Dark and Minimal. Dark comes first in the list. |

Other points:

- A keyword matches whole words only. "car" does not match "Cartoon". A plural with "s" or "es" matches.
- **Gaming** matches `video game`, `pc game`, `action-adventure game`, `shooter game`, `gaming`, `esports`, `game controller` and `joystick`. A plain `game` does not count, because Vision also uses it for dice, cards and ball games.
- "Fictional character" alone maps to Anime. A matching game label beats it because game labels are in the Subject tier.
- `CATEGORY_NAMES` did not change. The app list in `lib/features/folders/domain/entities/smart_rule.dart` must stay the same as it.
- Prism Studio walls get their category from the Studio plan (`functions/src/studio/plan.ts`). The classifier does not change them.

#### Recategorize script

`functions/src/scripts/backfillWallCategories.ts` gives approved walls the category that the current rule gives. It reads the stored `visionLabels`. It calls no paid service and no Vision API.

It skips these walls:

- Prism Studio walls (`origin` is `studio`).
- Walls with a category that a creator or an admin picked. The classifier sets `aiCategorized: true` when it writes a category. A wall without that flag and with a category other than General has a picked category.
- Walls with no labels or invalid labels.
- Walls in Gaming or Pastel (a rule from #574).

An admin who edits `category` directly in the console does not clear `aiCategorized`. The script cannot see that edit. On 2026-11-13, each classifier-owned wall had the category that the old rule gives, so no such edit existed.

- A dry run is the default. It reads approved walls and writes nothing. It prints each wall that would change, the 20 most common moves and up to 10 sample ids.
- `--classified-only` skips General walls that the classifier never set.
- `--apply` writes `category`, `aiCategorized` and `categorizedAt`. It writes in pages of 300 walls through a bulk writer. It does not change the collections of a wall. Get the owner's OK first.
- Each write requires the update time that the scan read. A later edit is thus not overwritten. If a write fails, the script prints the summary and exits with an error.

```sh
cd functions && npm run recategorize:walls            # dry run
cd functions && npm run recategorize:walls -- --apply # owner's OK only
```

The dry run on 2026-11-13 read production. It scanned 2,636 approved walls and wrote nothing. It skipped 228 Studio walls, 190 walls without labels and 5 picked categories. 67 walls change:

| Move | Walls |
|---|---|
| Nature to Architecture | 14 |
| Architecture to Abstract | 12 |
| Nature to Space | 11 |
| Dark to Minimal | 10 |
| Nature to Landscape | 8 |
| Anime to Dark | 2 |
| Nature to Dark | 2 |
| Architecture to Cars | 2 |
| Anime to Abstract | 2 |
| Dark to Cyberpunk | 1 |
| Architecture to Neon | 1 |
| Anime to Space | 1 |
| Anime to Galaxy | 1 |

Two of the 67 moves are worse. `ekfFrL8tagUJIpVDgG5i` is an anime wall where Vision put "Anime" tenth, after "Moon". It goes to Space. `mGo0EYRjYKdloYy20iNP` is an anime wall where "Star" ranks above "Fictional character". It goes to Galaxy.

#### Other lists

- Wall requests (#742) accept Pastel and Gaming as tags. The lists are `REQUEST_CATEGORIES` in `functions/src/wallRequests.ts` and `wallRequestCategoryTags` in the app. They must match.
- The typed event `category_opened` has `category` (the stable English name, such as `Pastel`) and `entry` (`collections` or `search`).
- The auto-rotate picker lists every classifier name, so it now shows Pastel and Gaming too. It uses Prism walls only, so these two have few walls until more uploads get the labels.

#### Web catalogue

The web catalogue does not read the app list. It groups approved walls by their stored `category` (`functions/src/webCatalog.ts`). Thus `/wallpapers/gaming` and `/wallpapers/pastel` and their sitemap entries appear at the next build after a wall has that category. The desktop hubs `/desktop-wallpapers` and `/matching-sets` already exist. No web change was made.

#### Deploy order

1. Deploy the Firestore index: `firebase deploy --only firestore:indexes`. Wait until the `walls (review, desktopVariant.v)` index is ready.
2. Deploy the functions: `make functions-deploy`. This ships the new classifier rules and the new wall request tags. Deploy it before the app release, because the server refuses a request tag it does not know.
3. Run the recategorize dry run, then `--apply` with the owner's OK.
4. If Remote Config `categories_v1` is set, it replaces the built-in list. Then add the Pastel, Gaming and Desktop entries to it, with their `query` values. Remote Config cannot express the Desktop tile, so a set `categories_v1` hides Desktop. Leave the key empty to show the built-in list.
5. Release the app.
6. The Desktop tile shows when 12 or more walls have a desktop version. Run the desktop backfill with the owner's OK. See [desktop-companions.md](desktop-companions.md).

### Screen behaviour

- The category bloc is shared. While the bloc still holds another category, the screen shows loading cards. It never shows the old category.
- A late page of the old category cannot join the new category.
- Collection and category tiles on the Collections tab decode by height only, so a photo keeps its shape.
- If the collection list fails to refresh, the old tiles stay.
- The error on the Collections tab reads "Couldn't load collections" with **Try again**.

### Long-press menu (quick actions)

A long press on a tile opens one sheet in these grids: home and category grids, search results, colour results, and collection walls.

| Row | When |
|---|---|
| **Favourite** or **Unfavourite** | Always. It changes the favourite and shows a message. |
| **Share link** | Always. It copies the link. |
| **Set as wallpaper** | Android only. It runs the normal set flow. |
| **Show less like this** | Only where the grid passes a callback. The home feed does. |

- A small heart (24 dp, bottom end) marks a tile in a home or category grid when the wallpaper is already a favourite. It reads the local favourites list. It has a tooltip and a screen reader label, "In your favourites". It does not take touches.
- Each grid used to do something different on a long press. They all open this sheet now.

## Limits

- A remote category gets Prism walls first only when its name is one of the 20 classifier names. A new classifier name needs a functions change and an app update.
- The heart badge shows only on home and category tiles. Search, colour and collection tiles do not show it.
- The badge reads the local favourites list. It can be late until the favourites load after sign-in.
- The long-press menu has no analytics event.
- The Prism-first list has no second page. After the first 24 Prism walls, the grid continues with the provider.
- The AMOLED tile is a plain Wallhaven search. Pure black walls are not guaranteed.
- A guest can open the sheet. Whether a guest can favourite depends on the favourites feature.
- Stock-only categories cannot be followed. A remote category can be followed only when its name matches a classifier name, in any letter case.

## How to test

1. Open **Collections**. Tap **Nature**. Make sure the first tiles are Prism creator walls, then Wallhaven walls.
2. Go back and tap **AMOLED**. Make sure dark wallpapers load.
3. On the Nature screen, switch to another category quickly. Make sure the old walls never show.
4. Long press a tile. Make sure the sheet opens with **Favourite**, **Share link** and (Android) **Set as wallpaper**.
5. Tap **Favourite**. Make sure the tile shows a small heart. Long press again. Make sure the row reads **Unfavourite**.
6. Long press a tile on the home feed. Make sure **Show less like this** shows.
7. Pull down on the Collections tab with airplane mode on. Make sure the collection tiles stay.
8. In a debug build, set `categories_v1` in Remote Config to the built-in list plus one new entry. Cold start the app two times. Make sure the new tile shows in Collections and in the search "Browse by Category" row, and that it loads walls.

Automated tests:

- `test/data/categories/category_catalog_test.dart`
- `test/features/category_feed/category_feed_repository_impl_test.dart`
- `test/features/user_search/search_discovery_semantics_test.dart`
- `test/features/category_feed/category_feed_bloc_test.dart`
- `test/features/category_feed/collection_view_screen_test.dart`
- `test/features/category_feed/source_feed_grid_test.dart`
- `test/features/category_feed/wallpaper_quick_actions_test.dart`
- `test/features/category_feed/collections_view_grid_test.dart`
- `test/features/category_feed/collections_grid_thumb_test.dart`
- `test/data/collections/collections_provider_test.dart`
- `test/features/prism_feed/data/repositories/prism_wallpaper_repository_impl_test.dart`

Command:

```sh
fvm flutter test --no-pub test/data/categories test/features/category_feed test/data/collections test/features/prism_feed
```
