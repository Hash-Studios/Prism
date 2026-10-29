# Creator stats

Open **Stats** on your own profile, on **Your uploads**, or in the creator progress card on **Rewards**. The upload entry is present when the upload list is empty. The review list continues to show pending and rejected uploads only.

The dashboard shows approved walls for the signed-in creator. It calls `getCreatorStats({})` when opened and on retry. A session identity change discards the old page BLoC and pending response before loading the new creator. Signing out clears the stats and shows the sign-in prompt. The server derives ownership from the authenticated UID. The client does not send a creator ID. The signed-in route is `/creator-stats`; the public deep link is `prism://creator-stats`.

Each metric shows this week so far, last week, the difference when both values exist, and its total. Weeks start on Monday at 00:00 UTC. The chart contains exactly eight weeks in oldest-first order. Select a metric to change the chart and the wall order. Walls are sorted by the current-week value, with unavailable values last. Equal values use the wall ID as a stable order. Select a wall to view its eight-week history from the same response.

A dash means that history is unavailable. Zero means that tracking recorded no activity. The client keeps these values separate. The current week is incomplete. Tracking can begin partway through a week, so a recorded value can cover only part of that week. The chart displays a localized date and exact number or unavailable label for every week. It also has a screen-reader summary that names the metric, all eight week dates, and each value or its unavailable state. Numbers and dates use the active locale. Controls wrap and the page scrolls when text is large. The chart uses theme colours and no motion.

Save totals count current favourite membership. Weekly saves count additions. Remix totals count current credited remixes. Weekly remixes count first accepted credits. Folder additions start when tracking starts. The app does not invent old history.

The repository validates the schema version, UTC timezone, eight contiguous Monday week boundaries, non-negative integer counts, and matching wall histories. A callable or parsing failure shows a retry action. An account with no approved walls sees Glint and an upload action.

The weekly inbox message uses copy kind `creatorStatsWeekly` with `{week: string}`. Its route is `creator_stats`. The localized title is **Your walls this week**. It opens the dashboard with analytics source `inbox`. The server owns notification eligibility, scheduling, and stored fallback copy.

Typed events are `creator_stats_opened` with `source`, `creator_stats_metric_switched` with `metric`, and `creator_wall_stats_opened` with `wall_id`. Entry sources are `profile`, `uploads`, `rewards`, `inbox`, and `link`.

## Integration and verification

The app needs the server callable and authenticated demo data before live verification. Deploy rules, indexes, and Functions before the store build. This document does not authorize a deploy.

Focused tests cover nullable counts, invalid histories, BLoC loading, loading and failure UI, empty state at large text, metric selection, wall detail, and chart semantics. Router, DI, localization, and analytics files are generated with the repository tools. The parent integration owns full `make ci` and device proof.

On this Linux host, the verification doctor cannot inspect iOS because `axe` is absent. An iOS Simulator run remains required on a Mac. Android proof must use only `Prism_QA_API36` on port 5580 and demo Firebase emulators. No production data is needed.

Independent review and local validation are recorded in `creator-stats-review.md`. Full `make ci` and device screenshots remain with the parent. No dependency change, push, merge, or deploy was performed.
