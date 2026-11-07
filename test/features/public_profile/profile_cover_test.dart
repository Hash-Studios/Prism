import 'dart:io';

import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_cover.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCover(WidgetTester tester, ProfileCover cover) async {
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 400, height: 160, child: cover)));
    await tester.pump();
  }

  Finder blurred(Finder finder) => find.descendant(of: find.byType(ImageFiltered), matching: finder);

  testWidgets('no custom cover: a blurred bundled wallpaper, chosen by the user id and stable', (tester) async {
    final String asset = ProfileCover.fallbackAsset('u2');
    expect(kCoverMosaicAssets, contains(asset));
    expect(ProfileCover.fallbackAsset('u2'), asset);

    await pumpCover(tester, const ProfileCover(url: '', seed: 'u2'));

    final Image image = tester.widget<Image>(blurred(find.byType(Image)));
    expect((image.image as ResizeImage).imageProvider, isA<AssetImage>());
    expect(((image.image as ResizeImage).imageProvider as AssetImage).assetName, asset);
  });

  testWidgets('no custom cover and a loaded wallpaper: that wallpaper, blurred', (tester) async {
    await pumpCover(tester, const ProfileCover(url: '', seed: 'u2', artUrl: 'https://example.com/latest.jpg'));

    expect(
      tester.widget<CachedNetworkImage>(blurred(find.byType(CachedNetworkImage))).imageUrl,
      'https://example.com/latest.jpg',
    );
  });

  testWidgets('the blur is clipped to the cover, so it cannot spill below the fade', (tester) async {
    await pumpCover(tester, const ProfileCover(url: '', seed: 'u2'));

    final Finder clipInCover = find.descendant(of: find.byType(ProfileCover), matching: find.byType(ClipRect));
    expect(find.ancestor(of: find.byType(ImageFiltered), matching: clipInCover), findsOneWidget);
    expect(tester.widget<ClipRect>(clipInCover).clipBehavior, isNot(Clip.none));
    expect(tester.getRect(clipInCover), tester.getRect(find.byType(ProfileCover)));
  });

  testWidgets('a picked cover is not blurred', (tester) async {
    await pumpCover(tester, ProfileCover(file: File(kCoverMosaicAssets.first)));

    expect(tester.widget<Image>(find.byType(Image)).image, isA<FileImage>());
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('a user-set cover shows as it is, not blurred', (tester) async {
    await pumpCover(tester, const ProfileCover(url: 'https://example.com/cover.jpg', seed: 'u2'));

    final CachedNetworkImage cover = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first);
    expect(cover.imageUrl, 'https://example.com/cover.jpg');
    expect(
      find.ancestor(of: find.byType(CachedNetworkImage).first, matching: find.byType(ImageFiltered)),
      findsNothing,
    );
  });
}
