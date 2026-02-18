You are building a new UI flow for the Prism app using the **Arsenal design system** — a cyberpunk / tech-noir aesthetic. The user's request follows this message. Implement it fully.

---

## Arsenal Design System Reference

### Single import
```dart
import 'package:Prism/core/arsenal/arsenal.dart';
```

---

### Colors — `ArsenalColors`
| Token | Hex | Use |
|---|---|---|
| `background` | `#000000` | Page background (AMOLED) |
| `surface` | `#111111` | Cards, containers |
| `surfaceVariant` | `#1C1C1C` | Elevated surfaces, input fields |
| `accent` | `#FC0053` | Brand red — CTAs, active states, highlights |
| `accentDim` | `#FC0053` 20% | Selection overlays, glows |
| `onBackground` | `#F0F0F0` | Primary text |
| `onSurface` | `#CCCCCC` | Secondary text on cards |
| `muted` | `#666666` | Captions, placeholders, inactive |
| `border` | `#2A2A2A` | Dividers, card outlines |
| `error` | `#FF4444` | Error states |
| `scrim` | `#000000` 60% | Image overlays for legibility |

Use `.withValues(alpha: x)` for opacity, **never** `.withOpacity()`.

---

### Typography — `ArsenalTypography`
All styles default to `color: ArsenalColors.onBackground`. Override with `.copyWith(color: ...)`.

| Style | Font | Size | Weight | Use |
|---|---|---|---|---|
| `hero` | BigShouldersDisplay | 48 | 800 | Screen hero titles — always UPPERCASE |
| `displayLarge` | BigShouldersDisplay | 40 | 800 | Major section headers — UPPERCASE |
| `displayMedium` | BigShouldersDisplay | 32 | 800 | Section headers |
| `subheadingLarge` | Rajdhani | 24 | 600 | Subheadings |
| `subheadingMedium` | Rajdhani | 18 | 600 | Card titles |
| `body` | Rajdhani | 16 | 500 | Body copy |
| `bodySmall` | Rajdhani | 14 | 500 | Secondary body |
| `buttonLabel` | Rajdhani | 14 | 700 | Button text — always UPPERCASE |
| `labelEmphasis` | Rajdhani | 13 | 700 | UI emphasis labels |
| `label` | Rajdhani | 12 | 600 | Standard UI labels |
| `monoHighlight` | JetBrainsMono | 13 | 700 | Step counters, status chips, codes — UPPERCASE |
| `mono` | JetBrainsMono | 12 | 400 | Timestamps, secondary technical text |

---

### Spacing — `ArsenalSpacing`
```
xs=4  sm=8  md=16  lg=24  xl=32  xxl=48  xxxl=64
iconSm=16  iconMd=24  iconLg=32
avatarSm=32  avatarMd=48  avatarLg=64
buttonHeight=52  chipHeight=32
```
**Zero border radius everywhere.** Arsenal is strictly sharp-cornered. Never use `BorderRadius`. Never use `RoundedRectangleBorder`. Never use `CircleBorder` except on `ArAvatar`.

---

### Components

#### `ArScaffold` — root of every Arsenal screen
```dart
ArScaffold(
  child: ...,
  extendBodyBehindAppBar: true,  // default
  appBar: ...,                    // optional
)
```
Wraps content in `arsenalDarkTheme`. **Every Arsenal page must use `ArScaffold` as its root.**

#### `ArButton` — three variants
```dart
ArButton.primary(label: 'CONFIRM', onPressed: () {})
ArButton.secondary(label: 'SKIP', onPressed: () {})
ArButton.ghost(label: 'CANCEL', onPressed: () {})

// Optional params (all variants):
width: double.infinity   // full-width
isLoading: true          // shows spinner
isDisabled: true         // 30% opacity, non-interactive
```
- Labels are auto-uppercased internally.
- Height is fixed at `ArsenalSpacing.buttonHeight` (52px).

#### `ArProgressSteps` — onboarding / step indicator
```dart
ArProgressSteps(total: 4, current: 0)  // 0-indexed
```
Active step expands (accent), others are small muted dots. Animated.

#### `ArChip` — filter / selection chip
```dart
ArChip(label: 'Dark', selected: true, onTap: () {})
```
Sharp rectangle. Selected: accent fill. Unselected: surface + border.

#### `ArAvatar` — user avatar
```dart
ArAvatar(imageUrl: user.photoUrl, initials: 'AB', size: 48)
```
Circular with accent border ring. Falls back to initials or person icon.

#### `ArTag` — status / category badge
```dart
ArTag(label: 'RECOMMENDED')
ArTag(label: 'NEW', color: ArsenalColors.error)
```
Sharp rectangle, JetBrainsMono, uppercase. Tinted fill + border at the given color.

#### `ArBottomSheet` — modal bottom sheet
```dart
ArBottomSheet.show(context,
  title: 'Choose Style',   // optional header
  child: ...,
)
```
Sharp corners, surface background, drag handle. Content is Arsenal-themed automatically.

---

### Aesthetic Rules (must follow strictly)

1. **Background is always `ArsenalColors.background` (`#000000`)** — set via `ArScaffold`, never override it.
2. **No rounded corners anywhere** — `BoxDecoration` never has `borderRadius`. Containers are rectangular.
3. **Accent (`#FC0053`) is used sparingly** — only on active/primary elements, CTAs, highlights. Not on body text.
4. **Text hierarchy**: hero/display for titles (BigShouldersDisplay), Rajdhani for all UI copy, JetBrainsMono only for technical/status text.
5. **Dividers and borders** use `ArsenalColors.border` (`#2A2A2A`) at 1px.
6. **Import sorting**: `package:Prism/` imports must come before `package:flutter/` and other packages (uppercase P sorts before lowercase in ASCII).
7. **No `@injectable`, `@freezed`, `@RoutePage`** in Arsenal files — pure Flutter/Dart only.
8. **Isolation**: Arsenal files import only `flutter/material.dart`, `google_fonts`, and each other (`package:Prism/core/arsenal/...`). Never import from `lib/theme/` or existing feature code.

---

### Common Patterns

**Full-screen page with header:**
```dart
ArScaffold(
  child: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(ArsenalSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TITLE', style: ArsenalTypography.hero),
          const SizedBox(height: ArsenalSpacing.sm),
          Text('Subtitle copy', style: ArsenalTypography.body.copyWith(color: ArsenalColors.muted)),
          ...
        ],
      ),
    ),
  ),
)
```

**Surface card:**
```dart
Container(
  padding: const EdgeInsets.all(ArsenalSpacing.md),
  decoration: const BoxDecoration(
    color: ArsenalColors.surface,
    border: Border(bottom: BorderSide(color: ArsenalColors.border)),
  ),
  child: ...,
)
```

**Accent divider / separator:**
```dart
Container(height: 1, color: ArsenalColors.accent)   // accent rule
Container(height: 1, color: ArsenalColors.border)   // standard divider
```

**Chip row (horizontal filter bar):**
```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.symmetric(horizontal: ArsenalSpacing.md),
  child: Row(
    children: ['All', 'Dark', 'Minimal'].map((label) =>
      Padding(
        padding: const EdgeInsets.only(right: ArsenalSpacing.sm),
        child: ArChip(label: label, selected: label == selected, onTap: () {}),
      ),
    ).toList(),
  ),
)
```

**Onboarding step layout:**
```dart
ArScaffold(
  child: Column(
    children: [
      Expanded(child: /* content */),
      Padding(
        padding: const EdgeInsets.all(ArsenalSpacing.md),
        child: Column(
          children: [
            ArProgressSteps(total: 4, current: step),
            const SizedBox(height: ArsenalSpacing.lg),
            ArButton.primary(label: 'CONTINUE', onPressed: onNext, width: double.infinity),
            const SizedBox(height: ArsenalSpacing.sm),
            ArButton.ghost(label: 'SKIP', onPressed: onSkip, width: double.infinity),
          ],
        ),
      ),
    ],
  ),
)
```

---

### File placement
New Arsenal flows live at:
```
lib/features/<feature_name>/views/pages/<screen_name>_page.dart
lib/features/<feature_name>/views/widgets/<widget_name>.dart
```

No code generation needed. Do not add `@RoutePage()` annotations unless the user explicitly asks to wire up routing.

---

Now implement the user's request below, following all rules above exactly.

$ARGUMENTS
