import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_setups/data/repositories/favourite_setups_repository_impl.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/in_memory_local_store.dart';

const String _collection = 'usersv2/user-1/setups';

void main() {
  late FakeFirestoreClient client;
  late FavoritesLocalDataSource local;
  late FavouriteSetupsRepositoryImpl repository;

  const setup = SetupEntity(
    id: 'SETUP1',
    image: 'https://example.com/setup1.jpg',
    name: 'Bloodland',
    email: 'creator@example.com',
    wallId: 'wall-1',
    source: WallpaperSource.prism,
    wallpaperUrl: 'https://example.com/wall-1.jpg',
  );

  setUp(() {
    client = FakeFirestoreClient(
      onQuery: (spec) => <FakeDocRow>[
        for (final entry in client.docs[spec.collection]?.entries ?? const <MapEntry<String, Map<String, dynamic>>>[])
          (id: entry.key, data: entry.value),
      ],
    );
    local = FavoritesLocalDataSource(InMemoryLocalStore());
    repository = FavouriteSetupsRepositoryImpl(client, local);
  });

  test('toggling a setup that is not a favourite stores it and remembers it locally', () async {
    final result = await repository.toggleFavourite(userId: 'user-1', setup: setup);

    final stored = client.docs[_collection]!['SETUP1']!;
    expect(stored['name'], 'Bloodland');
    expect(stored['wall_id'], 'wall-1');
    expect(stored['wallpaper_provider'], WallpaperSource.prism.legacyProviderString);
    expect(local.isSetupFavourite('user-1', 'SETUP1'), isTrue);
    expect(result.data?.map((s) => s.id), <String>['SETUP1']);
    expect(result.data?.single.wallId, 'wall-1');
  });

  test('toggling a favourite removes it and forgets it locally', () async {
    await repository.toggleFavourite(userId: 'user-1', setup: setup);

    final result = await repository.toggleFavourite(userId: 'user-1', setup: setup);

    expect(client.docs[_collection], isEmpty);
    expect(local.isSetupFavourite('user-1', 'SETUP1'), isFalse);
    expect(result.data, isEmpty);
  });

  test('reports a failure when the list cannot be read', () async {
    client.queryError = StateError('offline');

    final result = await repository.toggleFavourite(userId: 'user-1', setup: setup);

    expect(result.isFailure, isTrue);
  });
}
