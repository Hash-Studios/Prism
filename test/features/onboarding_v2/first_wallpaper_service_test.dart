import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/onboarding_v2/src/services/first_wallpaper_service.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCategoryFeedRepository extends Mock implements CategoryFeedRepository {}

class _MockWallOfTheDayRepository extends Mock implements WallOfTheDayRepository {}

void main() {
  late _MockWallOfTheDayRepository wotdRepository;
  late FirstWallpaperService service;

  setUp(() {
    wotdRepository = _MockWallOfTheDayRepository();
    service = FirstWallpaperService(_MockCategoryFeedRepository(), wotdRepository);
  });

  void stubWotd(Result<WallOfTheDayEntity?> result) =>
      when(() => wotdRepository.fetchToday()).thenAnswer((_) async => result);

  test('without interests the wall of the day is the recommendation', () async {
    stubWotd(
      Result.success(
        const WallOfTheDayEntity(
          wallId: 'w1',
          url: 'https://example.com/full.jpg',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          photographer: 'Ana',
        ),
      ),
    );

    final vm = await service.recommendForOnboarding(const <String>[]);

    expect(vm?.fullUrl, 'https://example.com/full.jpg');
    expect(vm?.thumbnailUrl, 'https://example.com/thumb.jpg');
  });

  test('a missing thumbnail falls back to the full image', () async {
    stubWotd(
      Result.success(
        const WallOfTheDayEntity(wallId: 'w1', url: 'https://example.com/full.jpg', thumbnailUrl: '', photographer: ''),
      ),
    );

    final vm = await service.recommendForOnboarding(const <String>[]);

    expect(vm?.thumbnailUrl, 'https://example.com/full.jpg');
  });

  test('no pick, an empty url or a failed fetch all mean no recommendation', () async {
    stubWotd(Result.success(null));
    expect(await service.recommendForOnboarding(const <String>[]), isNull);

    stubWotd(Result.success(const WallOfTheDayEntity(wallId: 'w1', url: '', thumbnailUrl: '', photographer: '')));
    expect(await service.recommendForOnboarding(const <String>[]), isNull);

    stubWotd(Result.error(const ServerFailure('offline')));
    expect(await service.recommendForOnboarding(const <String>[]), isNull);
  });
}
