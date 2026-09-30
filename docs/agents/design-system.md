# Prism design system

This is the source of truth for Prism UI. `.impeccable.md` holds the product and brand intent. This file holds the
rules and the API. Import everything with one line:

```dart
import 'package:Prism/core/widgets/prism/prism_ui.dart';
```

## The look

Prism is a gallery. The wallpaper is the hero and the chrome is quiet.

- One page background (`colorScheme.surface`). Content sits on it directly.
- Cards are for grouped controls and facts, not for every block. Never put a card in a card.
- One accent-filled action per screen. Everything else is neutral.
- Titles are large and left-aligned. Fraunces is for numbers and hero lines only.
- Glint carries the emotion: empty, error, loading and success moments. Never on a grid or a preview.
- Motion is short and starts fast. It confirms a tap or shows where something came from.

## Colour

Use `Theme.of(context).colorScheme`. Every role follows the active theme variant and the user accent.

| Need | Use | Do not use |
|---|---|---|
| Page background | `cs.surface` | `theme.primaryColor`, `Colors.black` |
| Card or raised fill | `cs.surfaceContainerHigh` | `theme.hintColor` |
| Sheet and dialog fill | theme default (`surfaceContainerLow`) | hard-coded colours |
| Text and icons | `cs.onSurface` | `cs.secondary`, `Colors.white` |
| Secondary text | `cs.onSurfaceVariant` or `PrismTextStyles.body` | `cs.secondary.withValues(alpha: .5)` |
| Hairline border | `cs.onSurface.withValues(alpha: 0.08)` | `Colors.grey` |
| Accent | `cs.primary`, text on it `cs.onPrimary` | `cs.error`, `accentColor(context)` |
| Destructive and errors | `cs.error`, text on it `cs.onError` | `Colors.red` |
| Neutral control fill | `cs.onSurface.withValues(alpha: 0.08)` | `Colors.white10` |

`cs.error` is a real red now. Older code used it as the accent: replace those uses with `cs.primary`.

On top of a wallpaper (detail screen, tiles, carousels) the theme does not apply. Use white text and icons on a
black scrim (`Colors.black.withValues(alpha: 0.38)` circles, or a bottom gradient). `PrismIconButton(onImage: true)`
does this.

Status colours that are not the accent: success `Color(0xFF2FBF71)`, warning `Color(0xFFFFB454)`. Use them only
for status, with an icon or a label next to them.

## Type

Use `PrismTextStyles`. Do not use `Theme.of(context).textTheme` roles or raw `TextStyle(`.

| Role | Style | Use |
|---|---|---|
| `display` | Fraunces 34 | One hero line: onboarding, paywall, a big moment |
| `screenTitle` | 28 w700 | Page title (the header does this for you) |
| `sheetHeadline` | 24 w700 | Sheet title (`PrismSheetBody` does this) |
| `sectionTitle` | 20 w700 | Section heading |
| `barTitle` | 17 w700 | Title in a compact bar |
| `cardTitle` | 16 w700 | Card heading |
| `rowTitle` | 15 w600 | Row title, labels |
| `button` | 15 w600 | Button label |
| `body` | 14 w500, 70% | Body copy |
| `caption` | 12 w500, 60% | Small supporting text |
| `eyebrow` | 11 w700 tracked | A label above a value. At most one per screen |
| `numeral(size)` | Fraunces | Big numbers: coins, streak, counts |

Proxima Nova weights: `w500` is regular, `w600` is bold, `w700` is extra bold. Never use `w400` or lower (thin).
Text on a wallpaper: copy the style and set `color: Colors.white`.

## Space and radius

- `PrismSpace`: `xxs 4`, `xs 8`, `sm 12`, `md 16`, `lg 20`, `xl 24`, `xxl 32`, `xxxl 40`. Page margin is
  `PrismSpace.page` (20). The gap between groups is at least twice the gap inside a group.
- A tab page ends with `SizedBox(height: PrismSpace.bottomBarClearance)` so the last item clears the bottom bar.
- `PrismRadius`: `xs 8`, `sm 12`, `md 16`, `lg 20` (cards), `xl 28` (sheets), `pill`. A nested surface takes the
  next step down. Wallpaper tiles in a grid use `PrismRadius.sm`.
- Tap targets are 44 points or more.

## Components

| Component | Use it for |
|---|---|
| `PrismPage(title:, body:, actions:, showBack:, headerBottom:, bottomBar:)` | Every pushed page. Large left title, back button, hairline on scroll. Tab roots pass `showBack: false`. |
| `PrismHeader` | The same header inside a custom scroll layout. |
| `PrismCard(child:, onTap:)` | A group of related controls or facts. |
| `PrismGroup(children:)` + `PrismRow` / `PrismSwitchRow` | Settings lists and menus. |
| `PrismRow(icon:, title:, subtitle:, value:, trailing:, onTap:, destructive:)` | Any list row. |
| `PrismSectionHeader(title:, actionLabel:, onAction:, small:)` | Heading above a group. |
| `PrismButton(label:, onPressed:, variant:, size:, icon:, loading:, expand:)` | Every button. `primary` once per screen, then `tonal`, `ghost`, `danger`. |
| `PrismIconButton(icon:, tooltip:, onPressed:, filled:, onImage:)` | Every icon-only button. The tooltip is required. |
| `PrismChip(label:, selected:, onTap:)` | Filters and choices. |
| `PrismTextField(label:, hint:, error:)` | Text input. |
| `showPrismSheet` + `PrismSheetBody(title:, message:, mood:, child:, actions:)` | Every bottom sheet. |
| `showPrismConfirm(context, title:, message:, confirmLabel:, destructive:)` | Every confirm. It replaces `AlertDialog`. The confirm label names the action. |
| `PrismSkeleton`, `PrismSkeleton.rows()`, `PrismSkeleton.cards()`, `PrismBone` | Loading lists and cards. `LoadingCards` for wallpaper grids. |
| `GlintState(kind:, title:, body:, actionLabel:, onAction:)` | Empty, error, offline, loading and nothing-new states. |
| `showGlintToast(context, mood:)` | A success moment: wallpaper set, upload sent, purchase done. |
| `toasts.success(msg)` / `toasts.error(msg)` | Short feedback. It is themed and sits above the bottom bar. |
| `PrismWallGrid.delegate(context)`, `PrismWallGrid.padding`, `PrismWallTile(url:, heroTag:, onTap:, onLongPress:, overlay:)` | Every grid of wallpapers. One spacing (8), margin (12) and radius (12) app-wide. `LoadingCards()` is its skeleton. |
| `PrismTag(label:, tone:)` | A status label: Pending, Approved, Pro, New. |
| `PrismAvatar(url:, name:, size:)` | Every profile picture. |
| `PrismSegmented(values:, selected:, labelOf:, onChanged:)` | Two to four exclusive choices. |
| `PressScale(child:)` | Press feedback on custom tappable surfaces (tiles, cards). |

Rules:

- No `AlertDialog`, `showDialog`, `showModal`, raw `showModalBottomSheet`, `SnackBar`, `MaterialButton`,
  `ElevatedButton` or `ListTile` in feature code. Use the components above.
- No full-screen `CircularProgressIndicator`. Use a skeleton that matches the content, or `GlintState(loading)` when
  the wait is long and the layout is unknown. A spinner is fine inside a button (`PrismButton(loading: true)`).
- Every list and grid has four states: loading, empty, error (with a retry action) and content.
- Icon-only buttons need a tooltip. Tappable custom widgets need `Semantics(button: true, label: ...)`.
- Icons: Material rounded (`Icons.*_rounded`) for new UI. Keep JamIcons where a glyph has no rounded match.

## Motion

Tokens live in `lib/core/motion/prism_motion.dart`.

- Durations: `PrismDurations.press` 100, `fast` 160, `base` 240, `slow` 320, `stagger` 40. UI motion stays under
  300 ms.
- Curves: `PrismCurves.enter` (strong ease-out) for things that arrive or leave, `move` for things that change place,
  `sheet` for sheets, `pop` for a small overshoot on a badge or a tick. Never `Curves.easeIn`.
- Wrap every duration in `context.motion(...)` so reduce motion turns it off.
- Animate only transform and opacity. Do not animate size, padding or position in a list that is on screen.
- Never start from scale 0. Start from 0.95 and fade.
- Press feedback is `PressScale` (0.96). Buttons and chips have it built in.
- A staged entrance (a page hero, a sheet's content) may stagger its parts by `PrismDurations.stagger`. Grid tiles,
  rows and anything the user sees many times a day do not animate in.
- Selection changes (tab, chip, toggle) cross-fade or slide in `fast`. They never jump.

## Glint

`Glint(mood:, size:)`. Moods: calm, happy, celebrate, love, surprised, curious, proud, worried, sad, sleepy.

| Moment | Mood | How |
|---|---|---|
| Empty list | calm | `GlintState(kind: empty)` |
| Nothing new, caught up | sleepy | `GlintState(kind: nothingNew)` |
| Error | sad | `GlintState(kind: error)` with a retry |
| Offline | worried | `GlintState(kind: offline)` |
| Long load, search | curious | `GlintState(kind: loading)` |
| Wallpaper set or saved, upload sent | happy | `showGlintToast` |
| Favourite added (first time in a session) | love | `showGlintToast(mood: love)` |
| Streak milestone, coins earned, purchase | celebrate | sheet with `PrismSheetBody(mood: celebrate)` |
| Sign-in prompt, onboarding hello | happy or curious | in the layout, 96 to 128 |

One Glint per screen. 48 points and up. Never on browse grids or wallpaper previews. The text next to Glint says
what happened. Only celebrate is loud.

## Copy

Short and plain. A button names its action ("Set wallpaper", "Delete account"). An error says what went wrong and
what to do. Sentence case everywhere. No "Oops", no exclamation marks on errors.
