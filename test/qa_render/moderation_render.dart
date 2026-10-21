@Tags(<String>['qa_render'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
import 'package:Prism/features/admin_review/biz/wall_moderation.dart';
import 'package:Prism/features/admin_review/views/pages/swipe_review_screen.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'home_render_support.dart';

class _MockReviewBatchBloc extends MockBloc<ReviewBatchEvent, ReviewBatchState> implements ReviewBatchBloc {}

class _FakeEvent extends Fake implements ReviewBatchEvent {}

const String _outDir = '/tmp/prism-qa/528';

final FirestoreDocument _wall = FirestoreDocument('qa1', <String, dynamic>{
  'title': 'Night ridge',
  'category': 'Nature',
  'by': 'Ann',
  'email': 'ann@example.com',
  'wallpaper_thumb': photoUrl('w05.jpg'),
  'depth': <String, dynamic>{'tier': 'auto'},
  'moderation': <String, dynamic>{
    'v': 1,
    'flags': <String>['duplicate', 'web_match', 'text'],
    'duplicate': <String, dynamic>{'wallId': 'abc123', 'similarity': 0.964, 'thumb': photoUrl('w09.jpg')},
    'web': <Map<String, String>>[
      <String, String>{'url': 'https://backdrops.app/wallpaper/night-ridge-4k', 'host': 'backdrops.app'},
      <String, String>{'url': 'https://www.pinterest.com/pin/123456789/', 'host': 'pinterest.com'},
      <String, String>{'url': 'https://wallpapers.example.org/mountains/ridge', 'host': 'wallpapers.example.org'},
    ],
    'words': <String>['@backdrops', 'HD', 'Wallpaper'],
    'logos': <String>[],
    'unsafe': <String>[],
  },
});

void main() {
  setUpAll(() async {
    registerFallbackValue(_FakeEvent());
    if (homeRender) await loadAppFonts();
  });

  void scene(String name, ThemeData theme, Future<void> Function(WidgetTester tester, HomeShot shot) body) {
    testWidgets(name, skip: !homeRender, (WidgetTester tester) async {
      final HomeShot shot = HomeShot(tester)..configureView();
      QaPhotoCache.install();
      final _MockReviewBatchBloc bloc = _MockReviewBatchBloc();
      when(() => bloc.close()).thenAnswer((_) async {});
      GetIt.I.registerSingleton<ReviewBatchBloc>(bloc);
      whenListen(
        bloc,
        const Stream<ReviewBatchState>.empty(),
        initialState: ReviewBatchState(
          status: ReviewBatchStatus.loaded,
          walls: <FirestoreDocument>[_wall],
          totalPending: 5,
        ),
      );
      try {
        await body(tester, shot);
        final RenderRepaintBoundary render = shot.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final ui.Image image = await render.toImage(pixelRatio: 3);
          final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final File file = File('$_outDir/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 11));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        QaPhotoCache.uninstall();
        await GetIt.I.reset();
      }
    });
  }

  Future<void> mount(WidgetTester tester, HomeShot shot, ThemeData theme, Widget home) async {
    await tester.pumpWidget(
      shot.frame(
        brightness: theme.brightness,
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: home,
        ),
      ),
    );
    await shot.settle(frames: 14, frameMs: 100);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await shot.settle(frames: 4, frameMs: 100);
  }

  for (final (String mode, ThemeData theme) in <(String, ThemeData)>[('light', kLightTheme), ('dark', kDarkTheme)]) {
    scene('swipe-$mode', theme, (WidgetTester tester, HomeShot shot) async {
      await mount(tester, shot, theme, const SwipeReviewScreen());
    });

    scene('sheet-$mode', theme, (WidgetTester tester, HomeShot shot) async {
      await mount(tester, shot, theme, const SwipeReviewScreen());
      await tester.tap(find.text('Looks like a Prism wall · 96%'));
      await shot.settle(frames: 6, frameMs: 120);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await shot.settle(frames: 4, frameMs: 100);
    });

    scene('list-card-$mode', theme, (WidgetTester tester, HomeShot shot) async {
      await mount(
        tester,
        shot,
        theme,
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ModerationCard(
                  previewUrl: photoUrl('w05.jpg'),
                  fullUrl: photoUrl('w05.jpg'),
                  facts: const <(String, String)>[('ID', 'qa1'), ('By', 'Ann'), ('Depth', 'Auto')],
                  moderation: wallModeration(_wall),
                  onApprove: () async {},
                  onReject: () async {},
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
