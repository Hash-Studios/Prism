# Original access rollout

This change protects new acquisition by canonical wall identity. It does not revoke public URLs or erase acquired local copies.

## Code boundary

Public wall documents contain `originalProtected: true`, `wallpaper_url: ''`, the immutable `originalGeneration`, and a preview URL.
Original provenance and storage locations stay in the server-only `ownedAssets` manifest.
Reviewed-wall queries include the protected marker and empty original field so Firestore can authorize the query.
The added composite indexes support those queries.

The server resolves current membership, Pro status, premium pass expiry, and coin prices.
Each original receipt binds the account, canonical `wall.id`, purpose, original generation, and request ID.
An issued URL is a bearer credential. Anyone with it can replay it until its 120-second expiry.
The same acquisition request can retry for five minutes without another charge, subject to current classification and entitlement checks.
Expired, refunded, revoked, or mismatched receipts do not grant access.

Original receipts cannot receive an automatic client-requested refund after URL issuance.
A signed URL cannot be recalled when a client reports a failed save.
Already acquired local files remain available under their existing account-bound acquisition records.
An arbitrary image cache entry does not establish acquisition.

## Release gates

Do not deploy tightened public-read rules before the approved metadata migration and compatible client rollout.
Old installed clients query reviewed walls without the new filters and will need an explicit rollout decision.
Do not treat a green PR or a deployed callable as proof that legacy originals are private.

Deployment requires a reviewed private storage bucket, signer permissions, the sibling owned-delivery functions, and indexes.
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
