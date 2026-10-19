# Owned asset delivery (#523)

When owned storage is enabled, Prism stores new wallpaper originals only in a private
Google Cloud Storage bucket. Thumbnail uploads and legacy uploads keep their existing
GitHub source and gain an independently retained copy. The private
`ownedAssets/{wall.id}` manifest binds exact object generations to a unique canonical
wall and its creation time. Public wall records expose an owned thumbnail URL,
`originalProtected: true`, `originalGeneration: <string>`, and `wallpaper_url: ''`.
Original delivery goes through server entitlement checks in #521 and a 120-second signed URL.
An owned marker alone is not proof: delivery also checks the private manifest and wall incarnation.
Thumbnails remain public, including pending submission thumbnails, as they already are
in the GitHub upload flow. This lets creators and moderators load retained previews.
Original authorization is separate. A thumbnail endpoint never returns an original object.

## Operator prerequisites

No bucket creation, IAM change, deploy or live migration is authorized by this document.
Obtain explicit approval at each concrete production step. Use ADC for the intended project,
and verify the project and runtime service account before running a command.

Configure these server environment names through the existing Doppler/deploy process:

- `OWNED_ASSET_BUCKET`: dedicated bucket name, without `gs://`.
- `OWNED_THUMBNAIL_BASE_URL`: HTTPS URL of the deployed `ownedThumbnail` function,
  without a wall id. The service appends `/<encoded wall.id>`.
- `GH_USERNAME` and `GH_REPO_WALLS`: exact trusted GitHub owner and wallpaper repository.
- Existing GitHub callable credentials remain server-only. Raw migration downloads do not send them.

Create the bucket in the approved project and region with uniform bucket-level access
and public-access prevention enforced. Do not grant `allUsers` or `allAuthenticatedUsers`
any bucket role. Do not configure Firebase download tokens or public object ACLs.
Do not expose this bucket through a public CDN or Firebase Storage rule. Do not apply
a lifecycle rule which removes retained generations still referenced by manifests.
Audit inherited organization/project grants as well as bucket grants.

The function runtime principal needs bucket-scoped `roles/storage.objectUser`
(create, read, metadata, delete). For signed URLs, enable the IAM Service Account
Credentials API and grant the runtime principal `roles/iam.serviceAccountTokenCreator`
on the signing service account, not broadly across the project. ADC migration operators
need Firestore read access for dry runs; apply additionally requires scoped Firestore
writes and bucket object creation/read. Retention uses create-only generation preconditions,
and rejects existing bytes or metadata that do not match.

Server Admin SDK access bypasses Firestore rules. Confirm clients cannot read or write
`ownedAssets` or mutate owned delivery markers. Coordinate these rules with #521:
do not deploy rules that reject writes from still-supported store clients without the
approved compatibility/adoption plan. An unrelated permissive rule must not expose the manifest.

## Safe rollout order

1. Approve and configure the private bucket, runtime IAM and environment. Verify no public access.
2. Deploy backend retention, binding, thumbnail delivery and entitlement-gated original delivery.
   Confirm actual function URLs before setting `OWNED_THUMBNAIL_BASE_URL`.
3. Verify new uploads retain both assets before publishing protected markers. Test original
   denial without entitlement, grant after acquisition, URL expiry, generation pinning,
   tombstones, missing assets and a reused logical wall id.
   New originals return an empty `download_url` with server-owned path/SHA receipts.
   Existing pending public-origin uploads require explicit reconciliation before retry.
4. Ship compatible clients and coordinate #521 rules with supported store versions.
5. Review a metadata-only dry run. Approve and execute bounded migration operations
   under the intended project. Review blocked rows and rerun after fixing their source.
6. Separately approve any GitHub source removal using a reviewed removal inventory.

These are separate gates. A local test pass does not establish deployed IAM, production
carrier reliability, entitlement behavior, or Android/iOS device behavior.

## Legacy migration

Build locally, then run the compiled script with explicitly selected project credentials:

```sh
cd functions
npm run build
node lib/scripts/migrateOwnedAssets.js
```

The default is a read-only dry run. It reads walls, private manifests, upload receipts
and intents. It does not download images, write Firestore or write Storage. The JSON
report includes the document path, logical `wall.id`, status and whether the GitHub
public original remains. Treat reports as private operational records. The scan checks
all canonical wall documents, including auto-generated legacy document ids; duplicate
logical ids block every matching record. Do not resolve duplicates by guessing which
document is canonical.

Modern provenance requires exact server-owned upload receipts and completed intents
for both assets, with a consistent uploader. Missing proof is blocked by default.
Dry-run planning cannot prove object availability or image integrity; apply performs
those checks before binding.

Some legacy records predate those receipts. An explicitly approved legacy policy allows
only `review: true` canonical walls with a unique logical id and two separate raw assets
under the configured owner/repository. The operator must review the corpus and provenance
before opting in; `review: true` is editorial review, not cryptographic ownership proof.
This policy stores private legacy provenance and uses the reserved retention identity
`legacy-migration`. It does not fabricate uploader receipts, ownership or creator rewards.
Unsafe URLs, ambiguous ids and unreviewed walls remain blocked.

Preview that policy without mutation:

```sh
node lib/scripts/migrateOwnedAssets.js --allow-reviewed-legacy
```

Only after explicit production approval, the apply form is:

```sh
node lib/scripts/migrateOwnedAssets.js --apply --confirm-approved-migration
# Add --allow-reviewed-legacy only if that separate policy was explicitly approved.
```

The confirmation flag is an operator acknowledgement, not an authorization service.
Never run apply merely to see what happens. The script currently scans the full corpus;
estimate memory and operation counts from the dry run before approving a production run.
There is no automatic live retry loop. A failed row is reported and other rows continue;
rerunning safely resumes content-addressed retention and reports already-bound manifests.
Partial failures can leave private retained objects or enriched receipts, but do not
publish a half-bound wall. Review these before any cleanup; no automatic deletion occurs.

Downloads accept only HTTPS `raw.githubusercontent.com`, the configured owner/repo,
one explicit ref segment and safe file segments. Existing path/SHA fields must match.
Redirects are errors. Downloads have a 15-second deadline and a 32 MiB streaming limit,
JPEG/PNG/WebP/GIF metadata/pixel limits, and verify a supplied Git blob SHA. Legacy assets without
an existing SHA have the Git blob SHA derived from fetched bytes. Both assets are fetched
before retention writes. Final binding rechecks the canonical wall and fences its incarnation
and source identity. Concurrent changes can block a row; inspect and rerun.

## Public-source removal is separate

Migration does **not** delete GitHub files, change GitHub repository visibility, purge
GitHub caches, or make a previously public source private. Clearing `wallpaper_url` is
not revocation. Each result reports `publicOriginalRemains: true`, including already-owned
records, because no approved source-removal proof exists in this tool.

Before claiming originals are private, create a separate reviewed removal inventory from
the private manifest: wall id, canonical path/incarnation, original and thumbnail source
URLs, repository paths/blob SHAs, retained generations/digests, and all other references
to each shared GitHub path. Get explicit approval before removal. Check Git history,
forks, mirrors and caches as separate exposure risks. Do not delete a shared path merely
because one wall was migrated. This script never performs source removal.

Already acquired local copies remain usable under the existing acquisition policy.
Signed-URL expiry limits future origin access; it cannot revoke copied bytes.
Deleting wall metadata tombstones its delivery manifest. It does not delete objects that
another wall may reference. The existing authorized file-delete flow deletes the retained
generation and tombstones every manifest that references it. Account deletion still
anonymizes published walls instead of removing them. Staged orphan cleanup requires a
separate reviewed inventory and approval; no background retention change is introduced.

## Proof and known gaps

Local tests cover metadata-only dry runs, logical-id duplicates, URL allowlisting,
legacy policy gating, fetch failure, partial-retention retries and public-source warnings.
They are not production Storage/IAM or device tests. Before rollout, capture Android
and iOS screenshots and test slow/offline/mobile-carrier networks, thumbnail fallback,
expired URL refresh and acquired-original persistence. Production migration, source
removal, backend/rules deployment and real device/carrier checks require separate proof.
