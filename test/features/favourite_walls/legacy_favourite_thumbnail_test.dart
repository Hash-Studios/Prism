import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';
import 'support/guest_store_fixture.dart';

void main() {
  test('legacy favourite with an unknown provider normalizes a stored Wallhaven crop thumb', () async {
    final repository = FavouriteWallsRepositoryImpl(
      FakeFirestoreClient(
        onQuery: (_) => <FakeDocRow>[
          (
            id: 'wall-id',
            data: <String, dynamic>{
              'provider': 'wallhaven_legacy',
              'url': 'https://w.wallhaven.cc/full/21/wall.jpg',
              'thumb': 'https://th.wallhaven.cc/small/21/wall.jpg',
            },
          ),
        ],
      ),
      FavoritesLocalDataSource(InMemoryLocalStore()),
      unusedGuestStore(),
    );

    final result = await repository.fetchFavourites(userId: 'user-id');

    expect(result.isSuccess, isTrue);
    final wall = result.data!.single;
    expect(wall, isA<LegacyFavouriteWall>());
    expect(wall.thumbnailUrl, 'https://th.wallhaven.cc/lg/21/wall.jpg');
  });
}
