# Winter Studio series and December Drop (plan)

Status: code is ready (series, `startsOff`, Drop theme). Nothing is generated or deployed. A paid run needs the owner's OK.

## Goal

Give the Winter theme (1 December to 6 January) fresh walls that match it: a "Winter" Studio series and a December Drop made from it. The copy stays neutral. It says "winter" and "holidays". It shows no religious symbols.

## Series entry for `functions/src/studio/series.ts`

The object is in `STUDIO_SERIES`. It has no `depth`, so it uses `STUDIO_COMPOSITION`. It has `startsOff: true`, so it makes no candidates until `seriesWeights["winter-light"]` is above 0.

| Field | Value |
|---|---|
| `id` | `winter-light` |
| `name` | `Winter Light` |
| `category` | `Nature` |
| `tags` | `["winter", "snow"]` |
| `style` | "Quiet winter scene with soft, even light. Cool blues and whites with one small warm light source. Clean shapes, fine snow and frost detail, calm and still, no clutter." |

### Subjects (30)

Each subject has an `id`, a `title`, a `prompt` and 2 `tags`. The first subject is `winter-frozen-lake`, not `frozen-lake`, because Paper Worlds already has `frozen-lake` and the 21-day cooldown is keyed by subject id. No subject shows a person, a tree with ornaments, a gift, a religious building or a religious symbol.

| id | Title | Prompt |
|---|---|---|
| `winter-frozen-lake` | Frozen Lake | a wide frozen lake with fine cracks in the ice under a pale sky |
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

- Drop week: Monday 7 December to Sunday 13 December 2026, week key `2026-W50`.
- Theme: `studioConfig/current.dropSeries = {"2026-W50": "winter-light"}`. The planner then takes only `winter-light` reserves, up to 10, oldest first.
- Reserves: Studio publishes a wall at about 20:00 UTC each day. A wall published from Monday 30 November to Sunday 6 December goes to the `2026-W50` Drop. In those 7 days only `winter-light` walls get a reserve, and up to 10 can wait. Walls of other series get no reserve.
- `dailyDropReserves` stays 1, so the week gives at most 7 Winter reserves. With weight 2 the series gets up to 2 candidates a day. If about half pass, the week gives about 7 (guess).
- Fallback: with fewer than 4 ready Winter reserves on 7 December, the Drop uses the normal mixed pick, and the log says why.
- A Drop wall never goes through the admin approval. An approval makes it public and takes it out of the Drop. Look at the reserved walls in the review list without approving them. Delete a bad one.
- Title: call `setDropTitle` with `weekKey: "2026-W50"` and `title: "Winter Drop"`. The last call push shows the title. The live push title stays "A new Drop is live", because installed apps localize it from a fixed key.
- Prices and pushes do not change.

## Cost per wall

Facts from `docs/features/studio.md`: the default model is GPT Image 2.5 Sunburst at `high` quality, about $0.07 per image. Each candidate also uses 3 Vision features (SafeSearch, text, logo).

| Item | Cost per candidate |
|---|---|
| Image (GPT Image 2.5 Sunburst, high) | $0.070 |
| Vision, 3 features at about $1.50 per 1,000 | $0.0045 |
| Total | about $0.075 |

The share of candidates that pass the checks and the review (admin approval for feed walls, a look for Drop reserves) is not measured for a new series. The table uses a guess of 50%.

| Plan | Candidates | Usable walls (guess) | Cost |
|---|---|---|---|
| December Drop | 12 | 6 that pass the automatic checks and a look | about $0.90 |
| Season, 17 Nov to 31 Dec | about 60 | about 30 | about $4.50 |
| Cost per approved wall | | | about $0.15 |

If the pass rate is 30%, the season costs the same and gives about 18 walls, about $0.25 per wall.

## Steps after the OK

Do these in this order. Each date is UTC.

1. Merge the PR and deploy functions (`processStudioCandidate`, `planStudioBatch`, `runStudioBatch`, `planWeeklyDrop`). Cost: none. `winter-light` has `startsOff: true`, so the daily plan does not take it after the deploy. Do not set its weight to 0 first: the flag does that.
2. Start one manual run with `seriesId: "winter-light"` and `count: 4`. Review the 4 candidates. Cost: about $0.30.
3. From 17 November, if the walls look right, set `studioConfig/current.seriesWeights["winter-light"]` to 2. Cost: about $0.15 a day, about $4.50 to 31 December (see the table above). These walls go to the normal review. A few get a reserve and go to the Drops of 23 and 30 November, at most 3 at a time.
4. Before 20:00 UTC on 30 November, set `studioConfig/current.dropSeries` to `{"2026-W50": "winter-light"}`. Call `setDropTitle` with `2026-W50` and `Winter Drop`. Cost: none.
5. On 4 December, count the ready Winter reserves in the review list. With fewer than 4, set `dailyDropReserves` to 2 for the rest of the week. Set it back to 1 on 7 December. Cost: none (the same candidates).
6. On 7 December at 00:30 UTC, `planWeeklyDrop` plans the Winter Drop. Check `drops/2026-W50`. If the log says "too few ready walls", the Drop is mixed.
7. On 1 January 2027, set `seriesWeights["winter-light"]` to 0. Cost: none after that.

Steps from the first plan that no longer apply:

- "Set the weight to 0 before deploy": `startsOff` does that now.
- "Run Winter first each day so it takes the reserve": since PR #881, a series with 3 waiting reserves gets no more, so a Winter Drop of 4 or more could not fill. The `dropSeries` theme replaces this trick.
