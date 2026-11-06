# Winter Studio series and December Drop (plan)

Status: plan only. Nothing is generated and no code in `functions/` changed. A paid run needs the owner's OK.

## Goal

Give the Winter theme (1 December to 6 January) fresh walls that match it: a "Winter" Studio series and a December Drop made from it. The copy stays neutral. It says "winter" and "holidays". It shows no religious symbols.

## Series entry for `functions/src/studio/series.ts`

Add one object to `STUDIO_SERIES`. Do not add `depth`. The series uses `STUDIO_COMPOSITION`.

| Field | Value |
|---|---|
| `id` | `winter-light` |
| `name` | `Winter Light` |
| `category` | `Nature` |
| `tags` | `["winter", "snow"]` |
| `style` | "Quiet winter scene with soft, even light. Cool blues and whites with one small warm light source. Clean shapes, fine snow and frost detail, calm and still, no clutter." |

### Subjects (30)

Each subject has an `id`, a `title`, a `prompt` and 2 `tags`. No subject shows a person, a tree with ornaments, a gift, a religious building or a religious symbol.

| id | Title | Prompt |
|---|---|---|
| `frozen-lake` | Frozen Lake | a wide frozen lake with fine cracks in the ice under a pale sky |
| `snow-cabin` | Snow Cabin | a small wooden cabin half buried in snow, one window lit warm |
| `pine-ridge` | Pine Ridge | a ridge of snow covered pines fading into soft fog |
| `frost-leaf` | Frost Leaf | a single leaf covered in fine frost crystals, close up |
| `aurora-snowfield` | Aurora Snowfield | a quiet aurora over an empty snowfield |
| `ice-cave` | Ice Cave | the blue glow inside an ice cave with smooth walls |
| `snow-bridge` | Snow Bridge | a small stone bridge over a dark stream, snow on its rail |
| `lamp-snow` | Lamp Snow | soft snow falling through the light of one street lamp |
| `mountain-dawn` | Mountain Dawn | a snow peak catching the first pale light of dawn |
| `snowflake-macro` | Snowflake | one six sided snowflake in sharp detail on dark blue |
| `frozen-waterfall` | Frozen Waterfall | a waterfall frozen into long blue icicles |
| `winter-harbor` | Winter Harbor | an empty harbor with snow on the jetty and still grey water |
| `fox-tracks` | Fox Tracks | a line of small animal tracks across fresh snow |
| `owl-branch` | Snow Owl | a white owl on a snowy branch, seen from below |
| `string-lights` | Window Lights | a row of warm string lights in a frosted window |
| `snow-dunes` | Snow Dunes | wind carved snow dunes with long blue shadows |
| `cocoa-steam` | Warm Cup | steam rising from a plain mug on a snowy window sill |
| `ice-bubbles` | Ice Bubbles | frozen air bubbles trapped in clear lake ice |
| `night-village` | Night Village | a distant village of small lit windows in a snowy valley |
| `birch-grove` | Birch Grove | white birch trunks in deep snow under a flat grey sky |
| `glacier-edge` | Glacier Edge | the blue face of a glacier above dark water |
| `snow-train` | Snow Train | a small red train crossing a snowy viaduct far away |
| `frost-window` | Frost Window | fern shaped frost patterns on a window pane |
| `deer-clearing` | Deer Clearing | a deer standing still in a snowy forest clearing |
| `moon-snow` | Moon Snow | a full moon over snow covered hills |
| `icicle-row` | Icicles | a row of icicles on a roof edge catching light |
| `lantern-path` | Lantern Path | a path of small lanterns through deep snow at dusk |
| `polar-sea` | Polar Sea | floating ice on a calm dark polar sea |
| `snow-garden` | Snow Garden | a small garden under fresh snow with soft round shapes |
| `starry-pass` | Starry Pass | a mountain pass under a clear winter star sky |

### Palettes (6)

| id | Name | Prompt |
|---|---|---|
| `glacier` | Glacier | cold glacier blue and white |
| `midnight-snow` | Midnight Snow | deep navy night with silver snow |
| `dawn-frost` | Dawn Frost | pale peach dawn over blue frost |
| `evergreen` | Evergreen | deep green pines with white snow |
| `ember-window` | Ember Window | cool blue scene with one warm amber light |
| `silver-mist` | Silver Mist | soft silver grey mist, low contrast |

### Cooldown and weight

- Keep `STUDIO_SUBJECT_COOLDOWN_DAYS` at 21. Each subject can run at most twice from 17 November to 6 January.
- Set `studioConfig/current.seriesWeights["winter-light"]` to 2 from 17 November to 31 December. A plan takes at most 2 walls of one category a day, and every subject is `Nature`, so the series gets at most 2 slots a day. After the first 15 days the 21-day cooldown limits it to about 1.4 a day.
- Set the weight to 0 on 1 January. Weight 0 leaves the series out of the plan (`plan.ts`), so no new winter walls come after the season.
- Other series also have `Nature` subjects. On days the series takes 2 `Nature` slots, those subjects wait.

## December Drop

- Week: Monday 7 December to Sunday 13 December 2026.
- 6 walls from `winter-light`, one from each palette.
- Use the existing `dailyDropReserves` path. From 30 November to 5 December, reserve the winter walls for the next Drop. Set `dailyDropReserves` to 1 and the weight to 2 in those 6 days.
- Use the normal Drop prices and pushes. The `live` push copy can say "Winter Drop".

## Cost per wall

Facts from `docs/features/studio.md`: the default model is GPT Image 2.5 Sunburst at `high` quality, about $0.07 per image. Each candidate also uses 3 Vision features (SafeSearch, text, logo).

| Item | Cost per candidate |
|---|---|
| Image (GPT Image 2.5 Sunburst, high) | $0.070 |
| Vision, 3 features at about $1.50 per 1,000 | $0.0045 |
| Total | about $0.075 |

The share of candidates that pass the checks and the admin review is not measured for a new series. The table uses a guess of 50%.

| Plan | Candidates | Approved walls (guess) | Cost |
|---|---|---|---|
| December Drop | 12 | 6 | about $0.90 |
| Season, 17 Nov to 31 Dec | about 60 | about 30 | about $4.50 |
| Cost per approved wall | | | about $0.15 |

If the pass rate is 30%, the season costs the same and gives about 18 walls, about $0.25 per wall.

## Steps after the OK

1. Add the series object to `functions/src/studio/series.ts` with a test that checks the ids are unique and no prompt has text or people.
2. Deploy functions.
3. Run one manual run of 4 candidates and review them. Expected cost: about $0.30.
4. If the walls look right, set the weight and the Drop reserve as above.
