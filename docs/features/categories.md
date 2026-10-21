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
| `lib/data/categories/categories.dart` | The 21 built-in category tiles. |
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

- 18 category names match the names that the upload classifier writes to `walls.category`: Nature, Architecture, Cars, Anime, Space, Ocean, Flowers, Neon, Dark, Abstract, 3D Render, Minimal, Gradient, AI Art, Cyberpunk, Vintage, Landscape and Galaxy. `CategoryDefinition.hasPrismWalls` is true for them. Aesthetic and Forest are not on the list.
- Page 1 of such a category first asks Firestore for up to 24 reviewed Prism walls with that category, newest first (`PrismWallpaperRepository.fetchByCategory`). The source tag is `category_feed.prism_first`. The query uses the index on `category`, `review` and `createdAt`.
- The repository puts those walls before the Wallhaven or Pexels walls. It removes a wall that is in both lists. It compares the full image address in lowercase.
- Page 2 and later come from Wallhaven or Pexels only.
- A creator that the user blocked never shows.
- If the Prism query fails, the page shows the provider walls and writes a warning to the log. A category with no Prism walls shows the provider walls only.
- The saved copy of the page (the offline fallback) includes the Prism walls.
- The grid shows Prism and provider tiles together. Analytics use the source context `category_prism_first` for a Prism tile in a provider category.

### AMOLED tile

- A new tile, **AMOLED**, searches Wallhaven for "amoled". Its picture is a dark Pexels photo.
- It has no Prism walls, because the classifier has no AMOLED category.

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

- A remote category gets Prism walls first only when its name is one of the 18 classifier names. A new classifier name needs a functions change and an app update.
- The heart badge shows only on home and category tiles. Search, colour and collection tiles do not show it.
- The badge reads the local favourites list. It can be late until the favourites load after sign-in.
- The long-press menu has no analytics event.
- The Prism-first list has no second page. After the first 24 Prism walls, the grid continues with the provider.
- The AMOLED tile is a plain Wallhaven search. Pure black walls are not guaranteed.
- A guest can open the sheet. Whether a guest can favourite depends on the favourites feature.

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
