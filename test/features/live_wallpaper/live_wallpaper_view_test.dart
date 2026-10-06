import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_capabilities.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_wallpaper_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_live_wallpaper_repository.dart';

void main() {
  late FakeLiveWallpaperRepository repository;
  late LiveWallpaperBloc bloc;

  Future<void> pump(WidgetTester tester, {String? imageUrl, bool isPro = false, VideoPicker? pickVideo}) async {
    bloc = LiveWallpaperBloc(repository, imageUrl: imageUrl)..add(LiveWallpaperEvent.started(isPro: isPro));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LiveWallpaperBloc>.value(
          value: bloc,
          child: pickVideo == null
              ? LiveWallpaperView(imageUrl: imageUrl)
              : LiveWallpaperView(imageUrl: imageUrl, pickVideo: pickVideo),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  setUp(() => repository = FakeLiveWallpaperRepository());

  testWidgets('shows a clear empty state when the device cannot do live wallpapers', (tester) async {
    repository.capabilities = LiveCapabilities.none;
    await pump(tester);
    expect(find.text('Live wallpapers are not available'), findsOneWidget);
    expect(find.text('Set live wallpaper'), findsNothing);
  });

  testWidgets('without a photo it opens on gradients and hides Make it live', (tester) async {
    await pump(tester);
    expect(find.text('Make it live'), findsNothing);
    expect(find.text('Gradients'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Battery saver'), findsOneWidget);
    expect(find.text('30 frames per second'), findsOneWidget);
  });

  testWidgets('battery saver switches to 15 frames per second', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('15 frames per second'), findsOneWidget);
    expect(bloc.state.batterySaver, isTrue);
  });

  testWidgets('a free user sees Pro styles locked and the button asks to unlock', (tester) async {
    await pump(tester);
    expect(find.text('Set live wallpaper'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));
    await tester.tap(find.text('Starfield'));
    await tester.pump();
    expect(find.text('Unlock with Prism Pro'), findsOneWidget);
  });

  testWidgets('a Pro user sees no locks', (tester) async {
    await pump(tester, isPro: true);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    await tester.tap(find.text('Starfield'));
    await tester.pump();
    expect(find.text('Set live wallpaper'), findsOneWidget);
  });

  testWidgets('applying a free gradient reaches the repository and tells the user to confirm', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(repository.gradientApplies, hasLength(1));
    expect(find.text('Confirm in the system preview.'), findsOneWidget);
  });

  testWidgets('a failure shows its message', (tester) async {
    repository.outcome = const LiveApplyOutcome.failed("Couldn't set the live wallpaper. Try again.");
    await pump(tester);
    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsOneWidget);
  });

  testWidgets('a repeated failure shows its message again after the first one is dismissed', (tester) async {
    repository.outcome = const LiveApplyOutcome.failed("Couldn't set the live wallpaper. Try again.");
    await pump(tester);
    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(LiveWallpaperView))).hideCurrentSnackBar();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsNothing);

    await tester.tap(find.text('Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't set the live wallpaper. Try again."), findsOneWidget);
  });

  testWidgets('video needs a pick before it can be set, and then applies it', (tester) async {
    await pump(tester, pickVideo: () async => '/tmp/loop.mp4');
    await tester.tap(find.text('Video'));
    await tester.pump();
    FilledButton button() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Set live wallpaper'));
    expect(button().onPressed, isNull);

    await tester.tap(find.text('Choose a video'));
    await tester.pump();
    await tester.pump();
    expect(find.text('loop.mp4'), findsOneWidget);
    expect(button().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Set live wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(repository.videoApplies, <String>['/tmp/loop.mp4']);
  });

  testWidgets('a rejected video shows the reason and keeps the button off', (tester) async {
    repository.videoProblem = 'That video is larger than 256 MB. Pick a shorter clip.';
    await pump(tester, pickVideo: () async => '/tmp/big.mp4');
    await tester.tap(find.text('Video'));
    await tester.pump();
    await tester.tap(find.text('Choose a video'));
    await tester.pump();
    await tester.pump();
    expect(find.text('That video is larger than 256 MB. Pick a shorter clip.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Set live wallpaper')).onPressed, isNull);
  });
}
