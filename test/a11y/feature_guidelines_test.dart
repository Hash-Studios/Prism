import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/live_tag.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/folders/biz/folder_discover_cubit.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/folders/views/widgets/discover_folders.dart';
import 'package:Prism/features/folders/views/widgets/folder_card.dart';
import 'package:Prism/features/folders/views/widgets/smart_rules_line.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/release_time_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/a11y_guidelines.dart';
import '../support/fake_user_block_repository.dart';

final DateTime _now = DateTime(2026, 11, 14, 10, 3);

Widget _frame(Widget child) => Scaffold(
  body: Center(child: SizedBox(width: 360, child: child)),
);

class _FakePublicFolders extends Fake implements PublicFoldersRepository {
  @override
  Future<Result<FolderDiscoverLists>> fetchDiscover() async => Result.success(FolderDiscoverLists.empty);

  @override
  Future<Result<Set<String>>> fetchFollowedIds(String userId) async => Result.success(<String>{});
}

class _FakeFavourites extends Fake implements FavouriteWallsRepository {
  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async =>
      Result.success(<FavouriteWallEntity>[]);
}

class _FakeFirestore extends Fake implements FirestoreClient {}

const DiscoverFolder _discoverFolder = DiscoverFolder(
  id: 'trend-1',
  ownerId: 'owner-a',
  name: 'Ocean Walls',
  itemCount: 12,
  ownerName: 'Ana',
);

void main() {
  setUp(() => PrismDeviceCornerRadius.setValueForTesting(48));

  testWidgets(
    'ReleaseTimeRow meets the tap target, label and contrast guidelines in every theme, text size and direction',
    (tester) async {
      await expectA11yGuidelines(
        tester,
        () => Scaffold(
          body: SingleChildScrollView(
            child: ReleaseTimeRow(releaseAt: DateTime(2026, 11, 15, 18).toUtc(), onChanged: (_) {}, now: () => _now),
          ),
        ),
      );
    },
  );

  testWidgets('LiveTag meets the tap target, label and contrast guidelines in every theme, text size and direction', (
    tester,
  ) async {
    await expectA11yGuidelines(tester, () => _frame(const LiveTag()));
  });

  testWidgets(
    'DiscoverFolderCard meets the tap target, label and contrast guidelines in every theme, text size and direction',
    (tester) async {
      final FolderDiscoverCubit cubit = FolderDiscoverCubit(
        _FakePublicFolders(),
        _FakeFavourites(),
        FakeUserBlockRepository.pending()..completeInitial(<String>{}),
        _FakeFirestore(),
        saveTraits: (_) async => <WallTraits>[],
      );
      addTearDown(cubit.close);
      await expectA11yGuidelines(
        tester,
        () => _frame(
          BlocProvider<FolderDiscoverCubit>.value(
            value: cubit,
            child: const DiscoverFolderCard(folder: _discoverFolder, tab: FolderDiscoverTab.trending, width: 200),
          ),
        ),
      );
    },
  );

  testWidgets(
    'SmartRulesLine meets the tap target, label and contrast guidelines in every theme, text size and direction',
    (tester) async {
      await expectA11yGuidelines(
        tester,
        () => _frame(
          SmartRulesLine(
            rules: const <SmartRule>[SmartRule(SmartRuleKind.colour, 'blue'), SmartRule(SmartRuleKind.followed)],
            onEdit: () {},
            loadCreatorNames: (_) async => const <String, String>{},
          ),
        ),
      );
    },
  );

  testWidgets(
    'FolderCard meets the tap target, label and contrast guidelines in every theme, text size and direction',
    (tester) async {
      await expectA11yGuidelines(
        tester,
        () => _frame(
          FolderCard(name: 'Ocean Walls', covers: const <String>[], itemCount: 12, coverSize: 160, onTap: () {}),
        ),
      );
    },
  );
}
