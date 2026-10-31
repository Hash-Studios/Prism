import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/features/creator_directory/views/widgets/visible_directory_creator.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Blocks extends Fake implements UserBlockRepository {
  final changes = StreamController<BlockedCreators>.broadcast();

  @override
  BlockedCreators get blockedCreators => KnownBlockedCreators(<String>[]);

  @override
  Stream<BlockedCreators> watchBlockedCreators() => changes.stream;
}

void main() {
  testWidgets('visible directory cards disappear when a creator is blocked', (tester) async {
    final blocks = _Blocks();
    getIt.registerSingleton<UserBlockRepository>(blocks);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: VisibleDirectoryCreator(uid: 'creator', child: Text('Creator')),
      ),
    );
    expect(find.text('Creator'), findsOneWidget);
    blocks.changes.add(KnownBlockedCreators(<String>['creator']));
    await tester.idle();
    await tester.pump();
    expect(find.text('Creator'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await blocks.changes.close();
    await getIt.reset();
  });
}
