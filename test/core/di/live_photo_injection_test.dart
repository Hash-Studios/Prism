import 'package:Prism/core/di/injection.config.dart';
import 'package:Prism/features/live_photo/data/repositories/live_photo_repository_impl.dart';
import 'package:Prism/features/live_photo/domain/repositories/live_photo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app container builds the Live Photo repository', () async {
    final GetIt container = GetIt.asNewInstance();
    addTearDown(container.reset);
    initGetIt(container);

    expect(container<LivePhotoRepository>(), isA<LivePhotoRepositoryImpl>());
  });
}
