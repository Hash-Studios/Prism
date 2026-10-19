# Original access rollout

This code introduces protected acquisition by canonical wall identity. It does not revoke public URLs or erase acquired local copies.

## Code boundary

Public wall documents contain `originalProtected: true`, `wallpaper_url: ''`, the immutable `originalGeneration`, and a preview URL.
Original provenance and storage locations stay in the server-only `ownedAssets` manifest.
Public reads also require explicit empty `wallpaper_path`, `wallpaper_sha`, `thumb_path`, and `thumb_sha` fields.
Thumbnail paths can reveal the corresponding original path, so clearing only the original URL is insufficient.
Reviewed-wall queries include the protected marker and all five empty fields so Firestore can authorize the query.
The added composite indexes support those queries.
Binding also redacts pending metadata. Owner/admin cleanup sends the canonical wall ID, original generation, and asset role.
The server resolves private file references and checks ownership and the current binding before cleanup.
Pending thumbnails remain public previews under the existing preview policy. Pending originals do not receive acquisition grants.
The delivery binder, signer, creator validation, and migration must use the private manifest after redaction.

The server resolves current membership, Pro status, premium pass expiry, and coin prices.
The client obtains a price-only quote before consent and caps acquisition at that price.
Two protected originals for Android pair Set use one quote and one atomic debit, including the shared free allowance.
Each original receipt binds the account, canonical `wall.id`, purpose, original generation, and request ID.
An issued URL is a bearer credential. Anyone with it can replay it until its 120-second expiry.
The same acquisition request can retry for five minutes without another charge, subject to current classification and entitlement checks.
The client keeps the owner-bound request through ambiguous replies and failed native operations.
An eligible receipt retry quotes zero additional coins rather than asking the user to authorize another payment.
Expired, refunded, revoked, or mismatched receipts do not grant access.

Original receipts cannot receive an automatic client-requested refund after URL issuance.
A signed URL cannot be recalled when a client reports a failed save.
Already acquired local files remain available under their existing account-bound acquisition records.
An arbitrary image cache entry does not establish acquisition.
This includes saved Prism-source descriptors when the index and native file agree.
Saved derivatives remain available locally but do not satisfy an original identity lookup.
Background rotation and Undo cannot buy access without consent. They reuse local copies or fail closed.
Onboarding has no purchase consent sheet. Its acquisition ceiling is zero coins; paid originals require the detail flow.

Prism share previews use the canonical owned-thumbnail endpoint, not a supplied thumbnail URL.
Unknown remote sources receive no remote share preview. Known external providers retain their existing preview behavior.

## Release gates

Do not deploy tightened public-read rules before the approved metadata migration and compatible client rollout.
Old installed clients query reviewed walls without the new filters and will need an explicit rollout decision.
Do not treat a green PR or a deployed callable as proof that legacy originals are private.

Deployment requires a reviewed private storage bucket, signer permissions, the sibling owned-delivery functions, and indexes.
Deploy the original-access callable in both configured app regions, including `us-central1`.
New original ingest must use private storage rather than create another public GitHub original.
The delivery implementation and dry-run migration belong to issue #523.

Before any production apply, inspect a dry run for every retained wall, original generation, preview, owner binding, and duplicate identity.
Obtain explicit approval for provisioning, secrets, deployment, migration apply, and removal of public originals at each final concrete step.
After migration, verify old GitHub, Firebase token, and other public URLs cannot retrieve original bytes.
Also inspect collection covers, previously stored short links, and cached OG images for historical original exposure.
Deleting a public source cannot recall copies already downloaded by others.

## Verification limits

Local callable tests exercise entitlement, classification, identity binding, replay, expiry, and refund refusal.
Client tests exercise canonical metadata and acquisition routes.
These tests do not prove a live bucket policy, object ACL, deployed signer, or old public URL removal.
An iOS Simulator and Android emulator run remain separate product gates.
