import 'dart:async';
import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/widgets/coins/coin_pill.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_follow_up.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_actions.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingAssetStore extends OfflineAssetStore {
  _PendingAssetStore() : super(directory: Directory.systemTemp);

  @override
  Future<File?> lookup(String source) => Completer<File?>().future;
}

final AiGenerationRecord _record = AiGenerationRecord(
  id: 'result',
  userId: 'user',
  createdAt: DateTime.utc(2026),
  prompt: 'A lighthouse',
  stylePreset: AiStylePreset.nature,
  qualityTier: AiQualityTier.fast,
  provider: 'test',
  model: 'test',
  seed: 1,
  width: 720,
  height: 1280,
  imageUrl: '',
  watermarkedImageUrl: '',
  chargeMode: AiChargeMode.freeTrial,
  coinsSpent: 0,
  status: 'success',
);

Future<void> _pumpResult(
  WidgetTester tester, {
  required ThemeData theme,
  double width = 320,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  Widget? trailing,
  Widget? notice,
  Widget actions = const SizedBox(height: 52),
  VoidCallback? onEdit,
  ValueChanged<AiFollowUp>? onFollowUp,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: direction, child: child!),
      ),
      // Deliberately no Scaffold/Material parent: the real page places this above its composing PrismPage.
      home: AiResultView(
        record: _record,
        isPremium: false,
        session: <AiGenerationRecord>[_record],
        generating: false,
        showFollowUps: true,
        followUpCost: 10,
        actions: actions,
        notice: notice,
        trailing: trailing,
        onEditPrompt: onEdit ?? () {},
        onSelectTake: (_) {},
        onFollowUp: onFollowUp ?? (_) {},
      ),
    ),
  );
}

RichText _richText(WidgetTester tester, String label) =>
    tester.widget<RichText>(find.descendant(of: find.text(label), matching: find.byType(RichText)));

void main() {
  setUp(() => OfflineAssetStore.testOverride = _PendingAssetStore());
  tearDown(() => OfflineAssetStore.testOverride = null);

  for (final ThemeData theme in <ThemeData>[kLightTheme, kDarkTheme]) {
    testWidgets('${theme.brightness.name} result keeps image ink white and panel ink themed without fallback lines', (
      tester,
    ) async {
      await _pumpResult(
        tester,
        theme: theme,
        width: 600,
        trailing: CoinBalancePill(balance: 90, onTap: () {}),
        notice: AiUnconfirmedNotice(onCheck: () {}),
        actions: AiResultActions(
          showSave: true,
          showRefine: true,
          canSubmit: true,
          sharing: false,
          applying: false,
          onApply: () {},
          onSave: () {},
          onShare: () {},
          onRefine: () {},
          onSubmit: () {},
        ),
      );

      final ColorScheme cs = theme.colorScheme;
      final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(AiResultView)));
      final TextStyle inherited = DefaultTextStyle.of(tester.element(find.byType(AiResultActions))).style;
      expect(inherited.fontFamily, theme.textTheme.bodyMedium!.fontFamily);
      expect(inherited.fontSize, theme.textTheme.bodyMedium!.fontSize);
      expect(inherited.color, cs.onSurface);
      expect(inherited.decoration ?? TextDecoration.none, TextDecoration.none);
      expect(_richText(tester, l10n.aiResultEditPrompt).text.style!.color, Colors.white);
      expect(_richText(tester, '90').text.style!.color, cs.onSurface);
      expect(_richText(tester, '10').text.style!.color, cs.onSurfaceVariant);
      expect(_richText(tester, l10n.aiFollowUpNight).text.style!.color, cs.onSurface);
      expect(_richText(tester, l10n.economyAiSubmissionUnconfirmed).text.style!.color, cs.onSurfaceVariant);
      expect(_richText(tester, l10n.aiResultApply).text.style!.color, cs.onPrimary);
      for (final RichText text in tester.widgetList<RichText>(
        find.descendant(of: find.byType(AiResultView), matching: find.byType(RichText)),
      )) {
        expect(
          text.text.style?.decoration ?? TextDecoration.none,
          TextDecoration.none,
          reason: text.text.toPlainText(),
        );
      }
      final Material root = tester.widget<Material>(
        find.descendant(of: find.byType(AiResultView), matching: find.byType(Material)).first,
      );
      expect(root.color, Colors.black);
      expect(root.elevation, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final TextDirection direction in TextDirection.values) {
    for (final bool withTrailing in <bool>[false, true]) {
      testWidgets(
        '320px 2x ${direction.name} keeps edit at start and ${withTrailing ? 'coins at end' : 'no trailing'}',
        (tester) async {
          var edits = 0;
          var coinTaps = 0;
          await _pumpResult(
            tester,
            theme: kLightTheme,
            direction: direction,
            textScale: 2,
            trailing: withTrailing ? CoinBalancePill(balance: 90, onTap: () => coinTaps++) : null,
            onEdit: () => edits++,
          );

          final Finder edit = find.ancestor(of: find.text('Edit prompt'), matching: find.byType(GestureDetector)).first;
          final Rect editRect = tester.getRect(edit);
          expect(editRect.height, greaterThanOrEqualTo(44));
          expect(editRect.left, greaterThanOrEqualTo(16));
          expect(editRect.right, lessThanOrEqualTo(304));
          expect(
            direction == TextDirection.ltr ? editRect.left : editRect.right,
            direction == TextDirection.ltr ? 16 : 304,
          );
          final RenderParagraph label = tester.renderObject<RenderParagraph>(find.text('Edit prompt'));
          expect(label.textScaler.scale(10), 20);
          expect(label.maxLines, 1);
          expect(label.overflow, TextOverflow.ellipsis);
          if (withTrailing) {
            final Rect coins = tester.getRect(find.byType(CoinBalancePill));
            expect(
              direction == TextDirection.ltr ? coins.right : coins.left,
              direction == TextDirection.ltr ? 304 : 16,
            );
            expect(editRect.overlaps(coins), isFalse);
            await tester.tap(find.byType(CoinBalancePill));
            expect(coinTaps, 1);
          }
          await tester.tap(edit);
          expect(edits, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Material keeps edit, follow-up and panel actions reachable with their semantics', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    var edits = 0;
    var applies = 0;
    var checks = 0;
    AiFollowUp? selected;
    await _pumpResult(
      tester,
      theme: kDarkTheme,
      width: 600,
      onEdit: () => edits++,
      onFollowUp: (value) => selected = value,
      notice: AiUnconfirmedNotice(onCheck: () => checks++),
      actions: AiResultActions(
        showSave: false,
        showRefine: false,
        canSubmit: false,
        sharing: false,
        applying: false,
        onApply: () => applies++,
        onSave: () {},
        onShare: () {},
        onRefine: () {},
        onSubmit: () {},
      ),
    );

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(AiResultView)));
    expect(
      tester.getSemantics(find.bySemanticsLabel(l10n.economyAiGeneratedWallpaper)),
      isSemantics(isImage: true, label: l10n.economyAiGeneratedWallpaper),
    );
    expect(
      tester.getSemantics(find.text(l10n.aiResultEditPrompt)),
      matchesSemantics(isButton: true, hasTapAction: true, label: l10n.aiResultEditPrompt),
    );
    await tester.tap(find.text(l10n.aiResultEditPrompt));
    await tester.tap(find.byKey(const ValueKey<String>('ai-follow-up-watercolour')));
    await tester.tap(find.text(l10n.economyAiCheckStatus));
    await tester.tap(find.text(l10n.aiResultApply));
    expect(edits, 1);
    expect(selected, AiFollowUp.watercolour);
    expect(checks, 1);
    expect(applies, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
