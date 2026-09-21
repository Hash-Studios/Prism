import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven_without_provider.dart' as wdata;
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async {
    await getIt.reset();
  });

  test('getWallsbyQuery throws when WallHaven fails, so search can fall back', () async {
    getIt.registerSingleton<WallhavenWallpaperRepository>(
      _FakeWallhavenRepository(Result.error<List<WallhavenWallpaper>>(const ServerFailure('503'))),
    );

    await expectLater(wdata.getWallsbyQuery('mountain', 100, 100), throwsException);
    expect(wdata.wallsS, isEmpty);
  });

  test('getWallsbyQuery returns an empty list when WallHaven finds nothing', () async {
    getIt.registerSingleton<WallhavenWallpaperRepository>(
      _FakeWallhavenRepository(Result.success<List<WallhavenWallpaper>>(<WallhavenWallpaper>[])),
    );

    expect(await wdata.getWallsbyQuery('zzzz', 100, 100), isEmpty);
  });
}

class _FakeWallhavenRepository implements WallhavenWallpaperRepository {
  _FakeWallhavenRepository(this.result);

  final Result<List<WallhavenWallpaper>> result;

  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
  }) async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
