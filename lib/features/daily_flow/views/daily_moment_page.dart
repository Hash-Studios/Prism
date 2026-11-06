import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_odds_sheet.dart';
import 'package:Prism/features/daily_flow/biz/daily_moment_cubit.dart';
import 'package:Prism/features/daily_flow/data/coins_daily_moment_repository.dart';
import 'package:Prism/features/daily_flow/domain/daily_moment_repository.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_odds_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:Prism/features/daily_flow/domain/daily_moment_repository.dart' show DailyMomentStep;

bool _showing = false;
bool _activeContent = false;

Future<void> showDailyMoment(
  BuildContext context, {
  DailyMomentStep? requestedStep,
  bool deepLink = false,
  StreakClaimResult? receipt,
}) async {
  if (_showing || _activeContent) return;
  _showing = true;
  try {
    await showPrismSheet<void>(
      context,
      useRootNavigator: true,
      detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
      builder: (_) =>
          DailyMomentContent(requestedStep: requestedStep, receipt: receipt, deepLink: deepLink, sheet: true),
    );
  } finally {
    _showing = false;
  }
}

@RoutePage()
class DailyMomentPage extends StatelessWidget {
  const DailyMomentPage({super.key, this.requestedStep, this.deepLink = false});
  final DailyMomentStep? requestedStep;
  final bool deepLink;
  @override
  Widget build(BuildContext context) => PrismPage(
    title: context.l10n.dailyMomentTitle,
    body: DailyMomentContent(requestedStep: requestedStep, deepLink: deepLink, showHeader: false),
  );
}

class DailyMomentContent extends StatefulWidget {
  const DailyMomentContent({
    super.key,
    this.requestedStep,
    this.receipt,
    this.deepLink = false,
    this.repository,
    this.sheet = false,
    this.showHeader = true,
  });
  final DailyMomentStep? requestedStep;
  final StreakClaimResult? receipt;
  final bool deepLink;
  final DailyMomentRepository? repository;

  /// Draws [PrismSheetBody] chrome. Only valid inside a [showPrismSheet] builder.
  final bool sheet;

  /// Plain layout only: the caption row with a close button.
  final bool showHeader;
  @override
  State<DailyMomentContent> createState() => _DailyMomentContentState();
}

class _DailyMomentContentState extends State<DailyMomentContent> {
  bool _ownsPresentation = false;
  late final DailyMomentRepository _repository = widget.repository ?? CoinsDailyMomentRepository();
  late final DailyMomentCubit _cubit = DailyMomentCubit(
    _repository,
    requestedStep: widget.requestedStep,
    receipt: widget.receipt,
    onStepDone: (step) =>
        unawaited(analytics.track(DailyMomentStepDoneEvent(step: DailyMomentStepValue.values[step.index]))),
  );

  @override
  void initState() {
    super.initState();
    if (_activeContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _activeContent = true;
    _ownsPresentation = true;
    unawaited(analytics.track(const DailyMomentShownEvent()));
    unawaited(_repository.markShown(_repository.accountId, _repository.now()));
    unawaited(
      _cubit.start().then((_) {
        if (!mounted || !widget.deepLink) return;
        final DailyMomentStep? step = widget.requestedStep ?? _cubit.state.step;
        if (step != null) {
          unawaited(analytics.track(DailyMomentDeepLinkOpenedEvent(step: DailyMomentStepValue.values[step.index])));
        }
      }),
    );
  }

  @override
  void dispose() {
    if (!_ownsPresentation) {
      super.dispose();
      return;
    }
    _activeContent = false;
    final DailyMomentStep? step = _cubit.state.step;
    if (!_cubit.state.done && step != null && !(step == DailyMomentStep.spin && _cubit.state.hasReceipt)) {
      unawaited(analytics.track(DailyMomentStoppedEarlyEvent(step: DailyMomentStepValue.values[step.index])));
    }
    _cubit.stop();
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_ownsPresentation
      ? const SizedBox.shrink()
      : BlocBuilder<DailyMomentCubit, DailyMomentState>(
          bloc: _cubit,
          builder: (context, state) {
            final l10n = context.l10n;
            final String title = state.done
                ? l10n.dailyMomentTitle
                : switch (state.step) {
                    DailyMomentStep.streak => l10n.dailyMomentStreakTitle,
                    DailyMomentStep.chest => l10n.dailyMomentChestTitle,
                    DailyMomentStep.spin => l10n.dailyMomentSpinTitle,
                    null => l10n.dailyMomentTitle,
                  };
            final String body;
            if (state.unavailable) {
              body = l10n.dailyMomentUnavailable;
            } else if (state.error) {
              body = l10n.dailyMomentError;
            } else if (state.receipt case final receipt?) {
              body = l10n.dailyMomentStreakReceipt(receipt.totalReward, receipt.streakCount);
            } else if (state.itemId != null) {
              body = l10n.dailyMomentCosmetic;
            } else if (state.coins case final coins?) {
              body = l10n.dailyMomentReward(coins);
            } else {
              body = switch (state.step) {
                DailyMomentStep.chest => l10n.dailyMomentChestBody,
                DailyMomentStep.spin => l10n.dailyMomentSpinBody,
                _ => l10n.dailyMomentBalance(state.balance),
              };
            }
            final bool finish = state.done || state.unavailable;
            final String primary = finish
                ? l10n.dailyMomentDone
                : state.error
                ? l10n.dailyMomentRetry
                : state.hasReceipt
                ? l10n.dailyMomentContinue
                : switch (state.step) {
                    DailyMomentStep.chest =>
                      state.chestCost == 0 ? l10n.dailyMomentOpenFree : l10n.dailyMomentOpenChest(state.chestCost),
                    DailyMomentStep.spin => l10n.dailyMomentSpinAction,
                    _ => l10n.dailyMomentContinue,
                  };
            final GlintMood mood = state.unavailable || state.done
                ? GlintMood.sleepy
                : state.error
                ? GlintMood.sad
                : (state.hasReceipt || state.coins != null || state.itemId != null)
                ? GlintMood.celebrate
                : switch (state.step) {
                    DailyMomentStep.chest => GlintMood.surprised,
                    DailyMomentStep.spin => GlintMood.curious,
                    _ => GlintMood.happy,
                  };
            final Widget button = PrismButton(
              label: primary,
              maxLines: null,
              expand: true,
              loading: state.busy,
              onPressed: state.busy
                  ? null
                  : finish
                  ? () => Navigator.of(context).pop()
                  : _cubit.primary,
            );
            final Widget details = Column(
              children: <Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(body, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
                ),
                if (!state.done &&
                    !state.unavailable &&
                    (state.step == DailyMomentStep.chest || state.step == DailyMomentStep.spin)) ...<Widget>[
                  const SizedBox(height: PrismSpace.xs),
                  PrismButton(
                    label: l10n.economyOddsTitle,
                    icon: Icons.info_outline_rounded,
                    variant: PrismButtonVariant.ghost,
                    size: PrismButtonSize.compact,
                    onPressed: () => state.step == DailyMomentStep.chest
                        ? showChestOdds(context, CoinPolicy.dailyChest)
                        : showWheelOdds(context, CoinPolicy.spinWheel),
                  ),
                ],
                const SizedBox(height: PrismSpace.md),
                PrismTag(label: l10n.dailyMomentBalance(state.balance), icon: Icons.toll_rounded),
              ],
            );
            if (widget.sheet) {
              return PrismSheetBody(
                mood: mood,
                title: title,
                centered: true,
                actions: <Widget>[button],
                child: details,
              );
            }
            return Column(
              children: <Widget>[
                if (widget.showHeader)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(PrismSpace.xl, PrismSpace.xs, PrismSpace.xs, 0),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text(l10n.dailyMomentTitle, style: PrismTextStyles.caption(context))),
                        IconButton(
                          tooltip: l10n.dailyMomentClose,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: PrismCenteredScroll(
                    action: button,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        GlintHalo(mood: mood),
                        const SizedBox(height: PrismSpace.xl),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: PrismTextStyles.sheetHeadline(context),
                          ),
                        ),
                        const SizedBox(height: PrismSpace.xs),
                        details,
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
}
