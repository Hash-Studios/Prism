# Legacy wallpaper thumbnail delivery

Issue [#523](https://github.com/Hash-Studios/Prism/issues/523) described GitHub raw as the only wallpaper host.
Current uploads already use R2 when configured. Legacy thumbnail copies still need an alternate host.

## Current delivery path

`upload_wall_screen.dart` calls `GitHubContentApi.putFile` with `purpose: wallpaper` for both image roles.
The `githubPutFile` callable in `functions/src/githubContent.ts` stores the original privately in R2 when enabled.
It returns a public R2 preview URL for the thumbnail. Without R2 routing, it retains the GitHub upload path.
`wallfirestore.dart` submits the returned `wallpaper_url` and `wallpaper_thumb` values.
The approval conversion in `ownedAssetDelivery.ts` protects originals and clears the public original URL.

`PrismWallDocMapper` maps those persisted URLs. Reviewed feed queries in `firestore_tracked_client.dart`
require protected walls with redacted original fields. Single-wall lookup enforces the same protection.
`WallpaperDisplaySource` uses the server's display derivative. Download, apply, and original-file share use
`OriginalAccessService` and signed R2 access. A raw-original rewrite would bypass that boundary.
See [owned asset delivery](owned-asset-delivery.md) for its configuration and migration requirements.

`mapFavouriteWallDoc` also reads URLs saved in old favourites. Those copies can retain raw GitHub thumbnails
after their canonical wall moves to R2. `PrismImageCache` now uses `LegacyThumbnailFileService` to fetch these
through `https://prismwalls.com/api/legacy-thumbs/<ref>/<path>`.
The stored URL, cache key, cache capacity, stale period, offline lookup, and retry eviction remain unchanged.
Other image providers and protected-original delivery keep their existing paths.

## Approve the Worker deploy before an app release

1. Review and approve deployment of the Worker in `infra/cloudflare/worker` through the existing release process.
   The route uses the existing `prismwalls.com/api/*` binding. No new bucket, DNS record, or secret is required.
2. Verify `GH_USERNAME` and `GH_REPO_WALLS` match the app's Doppler build configuration.
   The checked-in Worker values are `codenameakshay2` and `prism-walls`.
3. After deployment, request a known `thumb_*` file through the new route. Check the image bytes and cache headers.
   Confirm an original filename returns 404 and cannot retrieve the original.
4. Release the app only after that check passes. Shipping the app first breaks uncached legacy thumbnails.
5. Verify a legacy favourite on Jio and Airtel. With raw GitHub blocked, its thumbnail must request only
   `prismwalls.com`. Verify a protected wall preview, download, apply, and share still use their R2 delivery path.

This PR does not deploy the Worker, release the app, or migrate data. It requires no Functions or rules deploy.
The existing R2 configuration remains necessary for current wall originals and previews.

## Limits and rollback

The proxy serves only `thumb_*` images up to 4 MiB in the configured repository. It does not proxy originals, profile photos,
cover photos, arbitrary URLs, or the changelog. Older installed app versions keep their existing behavior.

The Worker introduces request and bandwidth usage under the existing Cloudflare plan. Cached thumbnails can
survive a GitHub outage while fresh. A cold or expired edge entry still needs GitHub. R2 is the independent
durable store for the current catalogue; this compatibility proxy is not a permanent archive.

Keep the Worker route available after the app ships. To roll back the app, preserve R2 access and the existing
protected-original rules. Do not restore public-original fallback. A deleted GitHub thumbnail can remain cached
at the edge for up to one day. An app can cache a late edge response for another day. Commit-ref URLs can still
retrieve files deleted from the branch. These cache lifetimes are not a deletion guarantee.
For urgent takedowns, remove access at the source and purge the Worker cache key
`https://prismwalls.com/__legacy-thumbs/v1/<owner>/<repo>/<ref>/<path>` for each affected ref and path.
Already downloaded or offline-retained copies cannot be recalled by an edge purge.
