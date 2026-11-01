# Store listings

The App Store and Google Play listing text for Prism, one file per locale. Nothing here reaches a store until a person runs the push commands below.

| Folder | Store | Format |
|---|---|---|
| `app-store/app-info/<locale>.json` | App Store | `name`, `subtitle` (app level) |
| `app-store/version/<version>/<locale>.json` | App Store | `description`, `keywords`, `promotionalText`, `whatsNew` (one version) |
| `play/<locale>/*.txt` | Google Play | `title`, `short_description`, `full_description` |
| `screenshot-captions/<locale>.json` | Both | Caption text for the current screenshot sets |

App Store files use the `asc metadata` layout. Play files use the `gplay metadata` layout.

## Check

```sh
make store-listings-check          # python3 tool/check_store_listings.py
```

The check fails on a field over the store limit, an App Store keyword word that repeats the name, the subtitle or another keyword, spaces around keyword commas, a competitor name, or a leftover placeholder. CI runs it in the `repo_assets` job.

| Field | Limit |
|---|---|
| App Store name, subtitle | 30 |
| App Store keywords | 100 |
| App Store promotional text | 170 |
| App Store description, What's New | 4000 |
| Play title | 30 |
| Play short description | 80 |
| Play full description | 4000 |
| Caption headline, subline (Prism rule) | 30, 60 |

## Locales

| Market | App Store | Play | Captions |
|---|---|---|---|
| UK and English fallback | `en-GB` (primary) | `en-GB` (default) | `en-GB` |
| United States | `en-US` | `en-US` | `en-US` |
| Germany | `de-DE` | `de-DE` | `de-DE` |
| Spain | `es-ES` | `es-ES` | `es-ES` |
| Mexico and Latin America | `es-MX` | `es-419` | `es-MX` |
| India | `hi` | `hi-IN` | `hi-IN` |
| Indonesia | `id` | `id` | `id` |
| Brazil | `pt-BR` | `pt-BR` | `pt-BR` |
| Portugal | `pt-PT` | `pt-PT` | `pt-PT` |

Play also has an old `fr-FR` listing. It is not part of this set, so the push commands below leave it out.

## Copy rules

- Platform. App Store copy may name iOS features (widgets, Spatial Scenes, Depth Effect, Duo, Shortcuts, guest browsing). Play copy may name Android features (set home, lock or both, live wallpapers, auto-rotate, Material You, the home screen widget). Never cross them.
- Timing. App Store description and What's New ship with the version folder they sit in. A Play listing goes live the moment it is pushed, so Play copy claims only features that are already in Play production.
- Register. Each locale uses the same form of address as the app: `du` (de), `tú` (es), `você` (pt-BR), `tu` (pt-PT), `Anda` (id), `आप` (hi). Feature names match the app strings in `lib/l10n/`.
- Keywords. Single words joined by commas with no spaces. Apple combines words from the name, subtitle and keywords, so a phrase such as "lock screen" needs each word only once. No competitor names.

## Keyword sets

Research on 2026-11-01 from store search results and competitor titles in each country. No source gave measured search volume, so each choice is a reasoned bet to check against App Store Connect and Play Console search data after release.

| Locale | Keywords | Why |
|---|---|---|
| `en-GB` | lock, screen, hd, aesthetic, anime, dark, black, depth, effect, spatial, 3d, generator, home, minimalist, cool | Apple also reads `en-GB` keywords in other storefronts (for example India, Germany, Indonesia), so this set holds the English head terms the native fields leave out. "generator" pairs with "AI" in the name. "depth effect" and "spatial" match iOS features few competitors claim. |
| `en-US` | backgrounds, hd, aesthetic, anime, dark, black, depth, effect, spatial, 3d, generator, home, minimalist, cool, art | The subtitle carries "lock screen widgets", the strongest US terms in competitor subtitles. "backgrounds" moves here from the `en-GB` subtitle. |
| `de-DE` | hintergründe, hintergrund, wallpaper, amoled, dunkel, schwarz, ästhetisch, anime, 3d, tiefeneffekt, homescreen | "Hintergrundbilder" (name) and "Hintergründe" lead German competitor titles. German compounds index as one word, so each form is listed. "Wallpaper" is a common loanword. |
| `es-ES` | bloqueo, inicio, wallpaper, estético, anime, negro, 3d, profundidad, efecto, espacial, generador, minimalista | "fondos de pantalla" (name) is the head phrase in Spain. "bloqueo" and "inicio" complete "pantalla de bloqueo" and "pantalla de inicio" with "pantalla" from the name. |
| `es-MX` | bloqueo, inicio, wallpaper, amoled, estéticos, anime, oscuro, 3d, profundidad, efecto, espacial, generador | Mexican listings say "celular" and "HD", so they sit in the subtitle. Apple also reads `es-MX` in the US storefront, which adds Spanish reach there. |
| `hi` | लॉक, स्क्रीन, होम, डार्क, एनीमे, एचडी, 3डी, कूल, स्टाइलिश, stylish, cute, photo, hd, backgrounds | Indian titles are mostly English. Devanagari forms of the same terms cover Hindi keyboards. Religious terms are left out because the catalogue does not target them. |
| `id` | hd, keren, kunci, layar, hp, 3d, anime, gelap, hitam, minimalis, aesthetic, background, efek, kedalaman, beranda | "wallpaper" (name) is the loanword Indonesians search. "HP" is the everyday word for phone. "kunci layar" and "keren" are common in local guides. |
| `pt-BR` | papéis, wallpaper, amoled, anime, estético, escuro, preto, 3d, efeito, profundidade, inicial, celular, gerador | "papel de parede" (name) is the default. Brazil has strong widget competition, so "widgets" and "tela de bloqueio" sit in the subtitle. "papéis" covers the plural that many Brazilian titles use. |
| `pt-PT` | wallpaper, amoled, anime, escuro, preto, 3d, efeito, profundidade, espacial, bloqueio, inicial, telemóvel, gerador | The name uses "fundos de ecrã" for Portugal. Portuguese store titles are mostly Brazilian, so the subtitle adds "papel de parede". |

## Push (a person runs these, after approval)

App Store. The only App Store version today is 3.8.0, waiting for review, and it cannot be edited. Create 3.18.0 first, then push. App-info fields (name, subtitle) become editable with the new version.

```sh
asc --profile prism metadata validate --dir metadata/app-store --subscription-app --output table
asc --profile prism versions create --app 6670200846 --version 3.18.0 --platform IOS --release-type MANUAL
asc --profile prism metadata push --app 6670200846 --version 3.18.0 --platform IOS --dir metadata/app-store --dry-run --output table
asc --profile prism metadata push --app 6670200846 --version 3.18.0 --platform IOS --dir metadata/app-store
```

Google Play. Push only after 3.18.0 is in production if any Play copy names a 3.18.0 feature (today none does).

```sh
gplay metadata validate --dir metadata/play --output table
gplay metadata push --package com.hash.prism --dir metadata/play --locales en-GB,en-US,de-DE,es-ES,es-419,hi-IN,id,pt-BR,pt-PT --dry-run
gplay metadata push --package com.hash.prism --dir metadata/play --locales en-GB,en-US,de-DE,es-ES,es-419,hi-IN,id,pt-BR,pt-PT --confirm
```

Pull again after a push to confirm the stores match the repo:

```sh
asc --profile prism metadata pull --app 6670200846 --version 3.18.0 --platform IOS --dir /tmp/asc-check --force
gplay metadata pull --package com.hash.prism --dir /tmp/play-check
```
