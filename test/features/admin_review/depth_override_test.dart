import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/features/admin_review/biz/depth_override.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FirestoreDocument wall(Object? depth) => FirestoreDocument('w1', <String, dynamic>{'review': false, 'depth': ?depth});

  test('reads the tier from the wall document', () {
    expect(wallDepthTier(wall(<String, dynamic>{'tier': 'auto'})), WallDepthTier.auto);
    expect(wallDepthTier(wall(<String, dynamic>{'tier': 'menu', 'by': 'admin'})), WallDepthTier.menu);
    expect(wallDepthTier(wall(<String, dynamic>{'tier': 'none'})), WallDepthTier.none);
  });

  test('a missing, broken or unknown depth map means not checked', () {
    expect(wallDepthTier(wall(null)), isNull);
    expect(wallDepthTier(wall('auto')), isNull);
    expect(wallDepthTier(wall(<String, dynamic>{'tier': 'sideways'})), isNull);
  });

  test('labels each tier and the unchecked state', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(WallDepthTier.values.map((WallDepthTier tier) => depthTierLabel(l10n, tier)), <String>[
      l10n.adminDepthTierAuto,
      l10n.adminDepthTierMenu,
      l10n.adminDepthTierNone,
    ]);
    expect(depthTierLabel(l10n, null), l10n.adminDepthTierNotChecked);
  });

  test('the local copy keeps the detector keys and takes the admin pick', () {
    final FirestoreDocument updated = withDepthOverride(
      wall(<String, dynamic>{'tier': 'none', 'kind': 'pet', 'top': 0.2, 'v': 1, 'by': 'detector'}),
      WallDepthTier.auto,
    );

    expect(updated.payload['depth'], <String, dynamic>{
      'tier': 'auto',
      'kind': 'pet',
      'top': 0.2,
      'v': 1,
      'by': 'admin',
    });
    expect(updated.payload['review'], isFalse);
    expect(updated.id, 'w1');
  });

  test('the local copy of an unchecked wall holds the whole map that is written', () {
    final FirestoreDocument source = wall(null);
    final FirestoreDocument updated = withDepthOverride(source, WallDepthTier.menu);

    expect(updated.payload['depth'], depthOverrideUpdate(source, WallDepthTier.menu)['depth']);
    expect(updated.payload['depth'], <String, dynamic>{
      'tier': 'menu',
      'by': 'admin',
      'v': 1,
      'kind': null,
      'top': null,
    });
    expect(source.payload.containsKey('depth'), isFalse);
  });
}
