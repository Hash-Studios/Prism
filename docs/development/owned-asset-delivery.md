# Owned wallpaper asset delivery

Prism keeps wallpaper originals private in `R2_PRIVATE_BUCKET`. It serves public thumbnails only from
`R2_PREVIEW_BUCKET` through the configured `R2_PREVIEW_BASE_URL` custom domain. The app and creator upload
flow continue to use GitHub as the source while R2 is not configured. Wallpaper clients explicitly identify
wallpaper uploads; profile photos, covers and other public uploads keep their existing GitHub delivery.
Enabling R2 is an explicit rollout;
this code change does not provision buckets, configure secrets, deploy functions or migrate live data.
No storage infrastructure has been provisioned or deployed by this PR.

The private `ownedAssets/{wall.id}` manifest binds stored objects to one canonical wall document and its
creation time. Public wall records contain `originalProtected: true`, `wallpaper_url: ''`, the original
object id, and the public preview URL. Server-only manifests keep source paths, Git SHAs, object ids,
SHA-256 digests and provenance. Protected-original access still goes through the existing entitlement
callable, which returns a short-lived R2 S3 presigned URL. Cloudflare documents that presigned URLs use
the S3 API endpoint and cannot use a custom domain. Preview URLs use the custom domain.

R2 object ids are stable SHA-256 identities derived from the uploader/source identity and byte digest.
Uploads use create-only writes; retries verify existing metadata and bytes rather than replacing an
object. The private and preview buckets are separate. No original is placed in the public preview bucket.
Existing GitHub-backed assets keep their GitHub receipt provenance during migration. A migration must not
claim them as new private-origin uploads or fabricate creator receipts. Legacy rows require explicit
reviewed-legacy opt-in and use a reserved migration identity.

## Runtime configuration

The Functions runtime uses these settings:

- `R2_ACCOUNT_ID`
- `R2_PRIVATE_BUCKET`
- `R2_PREVIEW_BUCKET`
- `R2_PREVIEW_BASE_URL`, an HTTPS custom domain attached to the public preview bucket
- `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`, configured as runtime secrets
- `GH_USERNAME`, `GH_REPO_WALLS` and existing GitHub callable credentials

Each function that accesses R2 must bind both R2 secrets. Configure the secrets through the approved
Doppler/deploy process only after production approval. Secret values must not be printed or checked in.
The account access key must be scoped to the two named buckets. Keep the private bucket non-public and
enable custom-domain access only for the preview bucket. Do not add lifecycle deletion that could remove
objects referenced by ready manifests. With no R2 routing configuration, uploads keep using GitHub. Any
partial R2 routing configuration fails closed; credentials alone may be staged before routing is enabled.
The deployment still requires its declared runtime secret bindings to be configured. Merging this PR
does not create those bindings. The first full Functions deployment, or deployment of any function that
binds R2 secrets, is blocked until the user approves secret setup and both secret versions exist.
This prerequisite also applies to a pre-rollout deployment with routing keys absent. Do not run the
default full Functions deployment for an unrelated hotfix before that approval. The default Makefile
secret-sync list does not include R2; use the explicit approved list below. Do not create placeholder
secrets or enable routing as an unapproved workaround.

After approval, include routing keys in the explicit Functions export list and R2 secrets in the sync list:

```sh
make functions-env FUNCTIONS_ENV_KEYS='GH_USERNAME GH_REPO_WALLS GH_REPO_SETUPS R2_ACCOUNT_ID R2_PRIVATE_BUCKET R2_PREVIEW_BUCKET R2_PREVIEW_BASE_URL'
make functions-secrets-sync FUNCTIONS_SECRETS='GH_TOKEN REVENUECAT_SECRET_KEY STUDIO_SECRET TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID FAL_API_KEY R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY'
```

These commands change local deployment configuration or sync secrets. Do not run them until the user
approves the concrete production configuration step. Mobile builds need `R2_PREVIEW_BASE_URL`, `GH_USERNAME`
and `GH_REPO_WALLS` as Dart defines. The GitHub defines keep existing public thumbnails usable during rollout.
The Doppler-to-Dart helper must exclude all R2 credentials, account id and bucket names from app
builds. The Worker needs no private-bucket credentials or a second R2 binding to embed the public preview
URL. Set its `R2_PREVIEW_BASE_URL` variable to the same HTTPS base URL as Functions and the app before
migrated walls are exposed in share/OG cards. Deploy that Worker change before metadata migration. Do not put bucket secrets in
`wrangler.toml`.
Set the Worker's `GH_USERNAME` and `GH_REPO_WALLS` variables to retain safe legacy GitHub thumbnails during rollout.
Put all three public variables under `[vars]` in the approved Wrangler configuration, using the examples in
`infra/cloudflare/worker/wrangler.toml`. For a named environment, put them under that environment's `vars` table.
Do not rely on dashboard-only variables; a Wrangler deploy can remove variables absent from its configuration.

## Delivery and deletion

An owned wall must have a unique logical `wall.id`, a ready private manifest, matching immutable wall
incarnation and an object id that agrees with the public marker. The original is never delivered from the
preview bucket. The public custom domain serves immutable preview objects without a per-request manifest check.
Upload receipt ownership, delete leases, quota accounting and server-side access checks
remain authoritative. A storage deletion must verify the expected object id and mark affected manifests
before retrying a delete. It must not fall back to deleting the corresponding GitHub asset.
The wall-delete trigger validates the original and thumbnail identities atomically against the matching
manifest incarnation and registry rows. It marks the manifest deleted and tombstones each unshared asset
so a delayed upload cannot republish it. It immediately deletes an unshared preview; the tombstone sweep
reclaims the private original and thumbnail copies after the cleanup grace period. Shared assets remain
active, and stale wall incarnations fail closed.
Admin cleanup of a reviewed-legacy manifest uses its exact wall incarnation and registry identity without
requiring a fabricated upload receipt or deleting the GitHub source. A shared ready preview stays available.
Uploads that never bind have no manifest for the wall-delete trigger to resolve. Use authorized path-mode
cleanup with the uploader receipt for these abandoned uploads; do not infer ownership from a filename.
Permanent registry tombstones prevent deleted identities from becoming active again. A daily cleanup scans
up to 100 tombstones per invocation and persists its cursor. Each full pass starts again so that a delayed
writer cannot leave an untracked object after a crash. This creates recurring Firestore reads and R2 requests.
Monitor cleanup failures and the time to complete a pass. Invalid identities are logged and skipped without deleting bytes.
Deleting an imported identity intentionally prevents re-import of that same identity. New user uploads use a
fresh upload incarnation so that an authorized re-upload can use the same file path safely.

## GitHub-to-R2 inventory and migration

The migration reads `walls` metadata and a recursive GitHub tree pinned to one commit. It refuses a
truncated tree. It reports referenced image paths, orphan image count, source Git blob SHA, byte size,
wall identity, duplicate ids and blocked reasons. Dry-run downloads no image bytes and writes no Firestore
or R2 objects. Its JSON report is private operational data and should be stored outside public source control.

The operator host needs Node.js, built Functions, read access to the configured public GitHub repository,
and Application Default Credentials for the approved Firestore project. Apply additionally needs scoped R2
credentials and Firestore write access. Do not use a production credential for local tests. Reports can
contain private source paths and must stay outside the repository.

Example metadata-only inventory:

```sh
cd functions
npm run build
node lib/scripts/migrateGithubToR2.js --ref master --report /secure/path/wall-assets.json
```

For a separate reviewed-legacy preview, include `--allow-reviewed-legacy`; this changes the recorded
policy and apply must use the same flag.

The report pins a commit SHA. Apply requires the exact commit SHA from that report, loads the existing report,
and rebuilds inventory from current Firestore and GitHub state. It refuses apply if paths, hashes, counts
or wall identities differ from the reviewed report. Reports include source URL hashes, approval status, and
Studio resolution. Source URLs and full wall documents are excluded. Reports created before these source
fingerprints require a new dry run. A trigger-converted wall must retain the reviewed source URLs in its
private manifest and the reviewed Studio identity, run, candidate, resolution, and approval status.
It then validates the same wall identity and paths before and after source download,
verifies each downloaded byte stream against the pinned Git blob SHA, and verifies R2 metadata/readback
before binding. It does not trust an old report as authorization or as proof that a wall is unchanged.
Create-only content-addressed writes make a rerun safe after interruption; the report records in-progress,
completed and blocked rows as work advances. Apply requires explicit operator approval at the final
concrete step:

```sh
node lib/scripts/migrateGithubToR2.js --ref <commit-SHA-from-report> --report /secure/path/wall-assets.json \
  --apply --confirm-approved-migration
```

Only add `--allow-reviewed-legacy` when that separate policy has explicit approval. It does not create
GitHub upload receipts, assign creator rewards, or claim uploader identity. Modern rows require matching
completed GitHub receipts and intents. A matching source Git SHA from the pinned tree fills old rows that
do not store a SHA; fetched bytes still must match that tree SHA.

An interruption after retention but before manifest binding can leave active unbound registry rows and R2
objects. The tombstone sweep does not reclaim these active orphans. Retries reuse the same content identity,
but successive source changes can leave more orphan objects. A separate reviewed orphan inventory and
approved cleanup are required. This change adds no destructive orphan cleanup.

Apply touches only the walls in the reviewed report. A wall added after the dry run is skipped, because
`onOwnedWallWritten` attempts conversion at approval. A wall deleted since the dry run is skipped. A reviewed
wall whose source changed still stops the run. A wall that the trigger already converted must match its
reviewed manifest and counts as done. Prism Studio walls are inventoried from their worker URL pair instead of
the GitHub tree. They need no flag: each is checked against its Studio candidate and stored with Studio
provenance, and gets no receipt or creator credit. `npm run migrate:github-to-r2 -- <options>` builds and runs
the script.

### User AI community walls

A user AI wall (`isAiGenerated: true`) records Worker URLs for one generation. The thumbnail is the watermarked
`ai/public/{generationId}.png`. The original is `ai/original/{generationId}.png` or the same public image, as the
wall recorded it. Only the Worker generation path writes these keys. The wall `id` must equal the id that the app
derives from the generation (`aiCommunityId`). The converter retains the recorded bytes. It does not change which
image a wall delivers. The recorded `resolution` is the requested size, and providers often return another size,
so the bytes are only decoded, not compared with it.

The owner proof is the server-owned Worker record `ai:gen:{generationId}`. Functions read it through the
secret-gated `GET /api/ai/studio/generation-records/{generationId}` route with `STUDIO_SECRET`. The route returns
the owner fields and omits the prompt. The record user must be the Firebase Auth user whose email posted the wall,
and that user must not be disabled. The manifest provenance is `{kind: "ai", generationId, uid}`.
`onOwnedWallWritten` applies this proof at approval, so it binds `STUDIO_SECRET`.

Worker records expire after 90 days. Client-writable `aiGenerations` documents do not prove ownership. An expired
record is accepted only by the bulk script under the separate `--allow-reviewed-ai-legacy` policy, and only when all
of these are true:

- The wall is approved.
- The Worker returns no record, and the time in the server-made generation id is more than 91 days ago.
  A missing record for a younger generation blocks the wall.
- The Worker still serves both images.
- No `aiGenerations` document names a user other than the wall author.

These walls use the reserved R2 owner `ai-legacy-migration` and the provenance `{kind: "ai-legacy", generationId}`.
They claim no uid. The trigger never applies this policy.

Neither AI provenance creates a GitHub receipt, creator credit or creator XP. Creator XP counts only `github` and
`owned` provenance, so AI walls earn no XP after conversion, as before it.

### Legacy Firebase Storage originals

An old wall can keep its original in the project bucket `prism-wallpapers.appspot.com` and its thumbnail on GitHub.
The dry run reads the public object metadata (generation, MD5, size), not the bytes, and pins them in the report.
Apply downloads the recorded URL and refuses bytes whose generation, MD5 or size differ. The original uses the
storage repo `firebase-storage` and the path `{bucket}/{object}`. The thumbnail comes from the pinned GitHub tree.
Firebase Storage has no upload receipts, so the wall needs `--allow-reviewed-legacy` and gets `{kind: "legacy"}`
provenance. The trigger does not convert these walls. The Firebase object stays unchanged.

### Cohorts on 2026-10-20

A read-only listing of approved walls found 2387 GitHub walls, 34 Studio walls, 12 user AI walls and 1 Firebase
Storage wall. The 12 AI generations were made from 2026-02-19 to 2026-06-13, so all their Worker records have
expired. Their client `aiGenerations` documents name the wall author. They need `--allow-reviewed-ai-legacy`.
The Firebase Storage wall (`P4EM`, 2020) needs `--allow-reviewed-legacy`. A dry run that includes them:

```sh
node lib/scripts/migrateGithubToR2.js --ref master --report /secure/path/wall-assets.json \
  --allow-reviewed-legacy --allow-reviewed-ai-legacy
```

The dry run needs `STUDIO_SECRET` in its environment to read Worker records. Without it, AI rows are blocked.
Deploy the Worker route before the dry run. Apply must use the same policy flags as the reviewed dry run.

Conversion also runs on every write of an approved wall that is still public (admin approval, 3.7.0 upload,
Studio wall, user AI wall with a live Worker record, released Drop wall). A permanent failure is logged as `owned wall conversion blocked`; the wall
stays hidden from 3.8.0 until a later write retries it or the bulk script converts it.

The script never deletes, privatizes or edits GitHub files. It does not revoke GitHub URLs, prior downloads,
Git history, forks, mirrors or caches. A separate removal inventory must check shared-path references and
receive explicit approval before any source-removal operation.

Preview object keys end in `.img` and are immutable by object id. Set object `Content-Type` metadata to the
detected image MIME type and use a public cache policy at the R2 custom domain. A preview delete does not
purge copies already held by edge or browser caches. Any approved preview-object removal must include a
Cloudflare cache purge plan; originals remain in the private bucket and are never routed through this domain.

## Rollout gates

Wall of the Day requires a pool of ready eligible walls. If that pool is empty, the picker logs an error
and sends no pick or push. Establish and verify that pool during rollout before expecting daily announcements.

1. Approve and create separate private and preview R2 buckets; configure scoped access credentials and the
   public preview custom domain. Disable public `r2.dev` access and keep all public access off the private
   bucket. Set a Cloudflare Cache Rule to cache `/previews/*.img`; this extension is not cached by default.
   No bucket or secret changes are included here.
2. Configure runtime secrets and deploy the Functions code through the approved deployment process.
3. Verify new uploads retain the expected private original and public-only preview. Test entitlement denial,
   successful acquisition, presigned URL expiry, retry behavior, object integrity and missing-object errors.
   Verify that profile and cover photo uploads still return usable public URLs and that both wallpaper
   upload roles use the explicit wallpaper purpose.
4. Preserve the GitHub upload path until R2 configuration and deployed delivery have been verified.
   Deploy the Worker preview allowlist and configure the app preview base before exposing migrated walls.
   Do not release a client that requires grants for a cohort until that cohort has ready manifests and
   its entitlement, preview, acquisition and retry checks pass against the deployed backend.
5. Run and review a dry-run inventory. Approve and execute apply separately, then inspect every blocked or
   partial result and rerun safely where needed.
6. Review and approve any GitHub removal as a separate operation.

If a pre-cutover check fails, keep routing absent so new uploads continue on GitHub. After a wall is marked
protected and its GitHub URL is redacted, do not remove R2 routing/secrets or roll back to a binary that
cannot read R2. Protected originals must fail closed, not fall back to a still-public GitHub URL. Keep R2
delivery configured for migrated walls; pause migration/new protected uploads or deploy a compatible fix.
Legacy GitHub copies remaining public does not make them an authorized app-delivery fallback.

## Cloudflare references

- [R2 S3-compatible API](https://developers.cloudflare.com/r2/api/s3/api/)
- [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)
- [R2 public buckets and custom domains](https://developers.cloudflare.com/r2/buckets/public-buckets/)
- [R2 pricing](https://developers.cloudflare.com/r2/pricing/)

The cited pricing page lists standard storage at $0.015/GB-month, Class A operations at $4.50/million,
Class B at $0.36/million, and no R2 egress charge. It also lists free monthly allowances of 10 GB-month
storage, 1 million Class A operations and 10 million Class B operations. Estimate cost as stored GB-month
times $0.015, plus Class A requests per million times $4.50 and Class B requests per million times $0.36,
after applicable allowances. No usage estimate is included because corpus bytes, request rates, retention
and cache hit rates have not been measured. The migration CLI transfers bytes from the operator host
directly from GitHub to R2, rather than through Firebase image delivery. New-upload Functions-to-R2
transfers may still incur provider compute or network charges. Functions execution and Firestore auth,
receipt and manifest operations also remain billable. R2's no-egress pricing is not a claim of zero total
cost. Check current pricing and actual usage before approval.
