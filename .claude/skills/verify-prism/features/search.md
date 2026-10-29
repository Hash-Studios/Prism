# Search

Search is the second bottom-nav tab (route `/dashboard/search`, `SearchRoute`). `lib/features/navigation/views/pages/search_tab_page.dart` wraps `SearchScreen` (`lib/features/user_search/views/pages/search_screen.dart`). User search is a nested route `/dashboard/search/users` (`UserSearchRoute`, `user_search_page.dart`).

## Sub-features

- `field`: hint `Search wallpapers`. `Clear search` clears it.
- `filters`: a `Filters` button opens a sheet with `Apply` and `Reset` (`search_filter_sheet.dart`).
- `discovery` (`search_discovery_widget.dart`, `search_discovery_sections.dart`): `Recent searches` with `Clear`, quick tag chips (`Nature`, `Architecture`, `Cars`, `Anime`, `Space`, `Ocean`, `Flowers`, `Neon`; `lib/features/user_search/data/search_tags.dart`), a `Find creators` row (subtitle `Search Prism users by name`), `Depth Effect, subject in front of the clock` (iOS only), `Spatial, walls with clear 3D depth`, `Browse by colour`, `Trending now`, `Browse by category` (cards labelled `Category, <name>`).
- `colour`: there is no `ColorRoute`. A swatch (label is the colour name, such as `Teal`) filters in place. A selected chip shows the colour (tooltip `Clear colour`). Tap that chip to clear it. A tap on the tooltip node does nothing.
- `user-search`: title `Find creators`, hint `Search creators`. A result tap pushes `ProfileRoute`.

## How to get to it (user POV)

- Tap `Search` in the bottom nav.
- Tap a trending wall for `features/wallpaper-detail.md`. Tap a category card to browse it. Tap a swatch to filter.
- Tap `Find creators` for user search.

## Driving it with the helper

Preconditions: app launched, signed in or out. Search does not need a session. User search does.

- **Landing.** Tap `Search`. Snapshot `--tag search-discovery`. Assert `Search wallpapers`, `Browse by colour`, `Trending now`, `Browse by category`.
- **Query.** Tap the field. Run `type --platform <p> --text "<word>"`. Confirm results render.
- **Colour.** Tap a swatch, such as `Teal`. Assert a selected `Teal` chip and a results grid. Tap the selected `Teal` chip to clear it.
- **Filters.** Tap `Filters`. Assert `Portrait only`, `Min resolution`, `Sort`, `Colour`, `Reset` and `Apply`. Tap `Close`.
- **User search.** Tap the `Find creators` text row (it is a text node, not a button). Signed out, assert the sign-in prompt and no field. Signed in, assert `Search creators`, type a name, then tap a result to open `ProfileRoute` (`features/profile.md`).
- **Proof.** Snapshot the landing, a colour result and a creator result.

## Gotchas

- `Depth Effect` shows on iOS only (`showDepthEffectUi`).
- Trending and category data need a real backend. A `SKIP_FIREBASE_INIT=true` build may show empty sections.
- Swatch labels come from `prismPaletteColorDisplayName`. Confirm names with `describe`.
