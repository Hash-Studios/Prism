// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_pickers.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f3_ai_generate_page.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

const MethodChannel _hapticsChannel = MethodChannel('prism/haptics');

Finder _styleTile(String label) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

/// The row opens on the selected style, so Anime (the first tile) starts off screen and must be scrolled into view.
Future<void> _scrollToAnime(WidgetTester tester) =>
    tester.dragUntilVisible(_styleTile('Style: Anime'), find.byType(AiStylePicker), const Offset(300, 0));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockOnboardingBloc bloc;
  late _MockCacheManager cache;
  late StreamController<FileResponse> pendingImage;

  setUpAll(() {
    registerFallbackValue(const OnboardingV2Event.started());
  });

  setUp(() {
    PrismHaptics.enabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _hapticsChannel,
      (call) async => null,
    );
    bloc = _MockOnboardingBloc();
    // The style samples request images through the cache. A stream that never emits keeps every sample loading.
    pendingImage = StreamController<FileResponse>();
    cache = _MockCacheManager();
    when(() => cache.getFileStream(any(), withProgress: true)).thenAnswer((_) => pendingImage.stream);
    PrismImageCache.testOverride = cache;
  });

  tearDown(() async {
    PrismImageCache.testOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_hapticsChannel, null);
    await pendingImage.close();
  });

  OnboardingV2State stateWith(AiGenerateStatus status) => OnboardingV2State.initial().copyWith(
    step: OnboardingV2Step.aiGenerate,
    aiData: OnboardingAiData(prompt: 'p', stylePreset: AiStylePreset.nature, status: status),
  );

  Future<void> pumpPage(WidgetTester tester, OnboardingV2State state, {Size size = const Size(393, 852)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(bloc, const Stream<OnboardingV2State>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<OnboardingV2Bloc>.value(value: bloc, child: const F3AiGeneratePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows the style picker with the aiData style marked as selected', (tester) async {
    await pumpPage(tester, stateWith(AiGenerateStatus.idle));

    expect(find.byType(AiStylePicker), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Style: Nature' && widget.properties.selected == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a style tile adds aiStyleSelected for that style', (tester) async {
    await pumpPage(tester, stateWith(AiGenerateStatus.idle));

    await _scrollToAnime(tester);
    await tester.tap(_styleTile('Style: Anime'));
    await tester.pump();

    verify(() => bloc.add(const OnboardingV2Event.aiStyleSelected(style: AiStylePreset.anime))).called(1);
  });

  testWidgets('a style tap adds nothing while the image is generating', (tester) async {
    await pumpPage(tester, stateWith(AiGenerateStatus.loading));

    await _scrollToAnime(tester);
    await tester.tap(_styleTile('Style: Anime'));
    await tester.pump();

    verifyNever(() => bloc.add(any()));
  });

  for (final size in const <Size>[Size(393, 852), Size(393, 760)]) {
    testWidgets('the style row stays above the preview at ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      await pumpPage(tester, stateWith(AiGenerateStatus.idle), size: size);

      final Rect row = tester.getRect(find.byType(AiStylePicker));
      final Rect preview = tester.getRect(find.byType(AnimatedSwitcher));
      expect(preview.height, greaterThan(0));
      expect(row.bottom, lessThanOrEqualTo(preview.top));
    });
  }
}
