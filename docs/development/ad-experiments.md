# Ad experiments

The experiment is off by default. Set Firebase Remote Config key
`ad_experiments_v1` to a JSON object with `version`, `native`, `banner`, and
`interstitial`. Each format flag is a boolean. Provide the corresponding
platform-specific AdMob unit IDs in `android_native_id`, `ios_native_id`,
`android_banner_id`, `ios_banner_id`, `android_interstitial_id`, and
`ios_interstitial_id`. Missing or invalid IDs disable that placement.

Use a new version only for a new assignment. A persistent random install seed
and the signed-in account ID determine the bucket. The same account remains
stable on that installation across sign-out, but can receive a different bucket
on another device or after app data is cleared. There is no server-authorized
experiment assignment endpoint; assignment is not globally account-stable.
Buckets 0 through 19 are the holdout.

The eligible signed-in account must be free, have completed onboarding, have
at least two completed sessions, and have current ad consent. A session is
completed after the app has been in the background for at least 30 minutes.
Native and banner impressions are capped once per session.
Interstitial impressions are capped once per UTC day and share a 30-minute
full-screen gap with other formats that call `recordFullscreen`.

Configure real, format-specific AdMob units for each platform before enabling
a format. App-open ads and rewarded interstitials are not part of this
experiment.

Debug builds select Google test units only after the configured platform unit
passes validation. SDK callback tests do not prove device rendering or live fill.
