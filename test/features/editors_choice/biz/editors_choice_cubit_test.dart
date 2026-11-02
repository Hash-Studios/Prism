import 'package:Prism/features/editors_choice/biz/editors_choice_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_editors_choice_repository.dart';

void main() {
  test('emits Loaded with the walls from the repository', () async {
    final FakeEditorsChoiceRepository repository = FakeEditorsChoiceRepository(walls: pickWalls(2));
    final EditorsChoiceCubit cubit = EditorsChoiceCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(limit: 30);

    expect(repository.requestedLimits, <int>[30]);
    final EditorsChoiceState state = cubit.state;
    expect(state, isA<EditorsChoiceLoaded>());
    expect((state as EditorsChoiceLoaded).walls.map((wall) => wall.id), <String>['pick-0', 'pick-1']);
  });

  test('emits Failed when the repository throws', () async {
    final EditorsChoiceCubit cubit = EditorsChoiceCubit(FakeEditorsChoiceRepository(fail: true));
    addTearDown(cubit.close);

    await cubit.load(limit: 30);

    expect(cubit.state, isA<EditorsChoiceFailed>());
  });
}
