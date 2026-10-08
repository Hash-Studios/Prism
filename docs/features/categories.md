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
| `lib/data/categories/categories.dart` | The 21 category tiles. |
| `lib/data/categories/category_definition.dart` | `CategoryDefinition` and `hasPrismWalls`. |
| `lib/features/category_feed/data/repositories/category_feed_repository_impl.dart` | Loads a category page. Puts Prism walls first. |
| `lib/features/prism_feed/data/repositories/prism_wallpaper_repository_impl.dart` | `fetchByCategory`. |
| `lib/features/category_feed/biz/bloc/category_feed_bloc.j.dart` | Category state. |
| `lib/features/category_feed/views/pages/collection_view_screen.dart` | The screen. |
| `lib/features/category_feed/views/widgets/source_feed_grid.dart` | The grid. |
| `lib/features/category_feed/views/widgets/wallpaper_tile.dart` | One tile. |
| `lib/features/category_feed/views/widgets/wallpaper_quick_actions.dart` | The long-press sheet. |

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

Automated tests:

- `test/features/category_feed/category_feed_repository_impl_test.dart`
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
fvm flutter test --no-pub test/features/category_feed test/data/collections test/features/prism_feed
```
