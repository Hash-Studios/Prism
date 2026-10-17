# Offline implementation contracts

The goal is a useful cold-started app with bundled or previously saved content. Remote catalogs are unbounded and are not all downloaded. Server-owned money, purchases, generation, publication, and deletion remain online.

## Storage choice

Use atomic, awaited JSON records and bounded feature-owned snapshots. Reuse the existing feed codecs. A local wallpaper catalog supports source-and-ID lookup and local search. A retained-original manifest is separate from temporary image caches.

Candidate A proposed a normalized per-record catalog with explicit assets and pending operations. Candidate B explored feature-owned snapshots and SDK persistence. Use A's durability and file resolver, with feature-owned snapshots to avoid duplicating every feature model. No new dependency is required. The cost is bounded local scans rather than a database query engine.

## Shared APIs

Worker 1 owns `lib/core/offline/durable_json_store.dart`.

```dart
class DurableJsonStore {
  DurableJsonStore(String name, {Directory? directory});
  Future<Map<String, Object?>?> read(String key);
  Future<Map<String, Map<String, Object?>>> readAll();
  Future<void> write(String key, Map<String, Object?> value);
  Future<void> delete(String key);
  Future<void> clear();
}
```

Writes complete only after atomic replacement. Failure must not poison later writes or expose an unpersisted success. Keys cannot escape the store directory. Corrupt records do not hide valid siblings.

The guarantee covers process interruption, not power loss. Every store has explicit record and byte limits. Replace-all snapshots use one atomic record or a generation pointer, not delete-then-reinsert.

Worker 1 owns `lib/core/offline/offline_asset_store.dart`.

```dart
class OfflineAssetStore {
  static OfflineAssetStore get instance;
  Future<File?> lookup(String source);
  Future<File> resolve(String source, {bool allowNetwork = true});
  Future<File> retain(String source, {File? file});
  Future<Map<String, String>> localPaths();
  Future<void> remove(String source);
  Future<void> clearRetained();
  Future<int> get storedBytes;
}
```

Local files and retained originals precede stale full-cache bytes, then network. `retain` owns a flushed completed copy before acknowledging the manifest. Retained files are not removed by temporary-cache cleanup. A bounded retained budget rejects a new save instead of silently evicting saved content. `localPaths` returns verified source-to-file mappings for native consumers.

Manifest paths are relative to the retained root. Verify file existence, length, image format, and root confinement when a mapping is consumed. Native consumers repeat these checks. Temporary and orphan files are repaired after an interrupted save. Retained bytes prove availability, not entitlement or acquisition. A cache hit alone does not waive a coin gate.

Private stores are keyed by owner. Public catalog records remain device-global. Feature-owned pending operations record owner, stable request ID, revision, desired state, and pending or rejected status. Their feature service replays them on start and reconnect, and acknowledges only the matching revision. A late old-owner response cannot write the active owner's state. Chargeable and destructive actions do not enter these queues. Account deletion clears user-owned snapshots, operations, drafts, prompts, and native mirrors.

Worker 2 owns `lib/data/offline/offline_wallpaper_catalog.dart`.

```dart
class OfflineWallpaperCatalog {
  static OfflineWallpaperCatalog get instance;
  Future<void> remember(Iterable<FeedItemEntity> items);
  Future<FeedItemEntity?> find(WallpaperSource source, String id);
  Future<List<FeedItemEntity>> search(String query, {int limit = 100});
}
```

## File ownership

1. Durable records, retained assets, core image caches, cache maintenance, storage controls.
2. Catalog, feed persistence and repositories, collections, WOTD, wallpaper and user search, detail-by-ID lookup.
3. Favourites, user blocks, public profiles, session repository and account mutation safeguards.
4. Main, startup, onboarding, notification persistence and inbox identity isolation.
5. Wallpaper service and actions, download integration, editor, position, tint, share, live textures, rotation.
6. Native Android and iOS consumers, quick-tile and Shortcut Flutter adapters, upload drafts, AI prompt and history persistence.

The parent owns DI generation, integration, docs, decision log, and PR operations. Workers do not run global code generation or commits. Workers add focused regression tests for their files. The parent reviews their exact changes and reruns the integrated gates.

## Throughput checkpoint

- Blocking first steps. Agree on storage signatures and capture existing audit/test baseline before migrations.
- Independent workstreams. The six file-owned slices above can proceed together after the signatures are fixed.
- Shared mutable state. One file owner and one generator owner. Runtime stores serialize only writes to their own records.
- Smallest safe decomposition. Keep each feature's model and lifecycle with its repository. Share only durability and image resolution.

## Completion gates

Every promised local journey has implementation and regression coverage. The current integrated tree passes local gates. The PR is open, linked, and its latest required CI checks pass. The user then verifies the real app on devices and adds before-and-after screenshots before merging. Tests and CI do not count as device proof.
