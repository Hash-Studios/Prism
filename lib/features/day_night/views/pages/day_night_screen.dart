import 'dart:async';

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_guide_sheet.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_phone_preview.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens Day and night as an in-app page. It has no route path, so it needs no deep-link or web allowlist entry.
Future<void> openDayNightScreen(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute<void>(builder: (_) => const DayNightScreen()));

class DayNightScreen extends StatelessWidget {
  const DayNightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DayNightBloc bloc = context.read<DayNightBloc>();
    final DayNightState state = context.watch<DayNightBloc>().state;
    final DayNightPair pair = state.pair;
    final DayNightTimes times = pair.times;
    final String dayTime = dayNightTimeLabel(context, times.dayStart);
    final String nightTime = dayNightTimeLabel(context, times.nightStart);
    final bool canSwitch = !state.preparing && pair.isComplete;

    return PrismPage(
      title: l10n.dayNightTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxl),
        children: <Widget>[
          Text(l10n.dayNightIntro, style: PrismTextStyles.body(context)),
          const SizedBox(height: PrismSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: DayNightPhonePreview(
                  slot: DayNightSlot.day,
                  wall: pair.day,
                  time: dayTime,
                  needsDownload: state.issue == DayNightIssue.needsDownloadDay,
                ),
              ),
              const SizedBox(width: PrismSpace.md),
              Expanded(
                child: DayNightPhonePreview(
                  slot: DayNightSlot.night,
                  wall: pair.night,
                  time: nightTime,
                  needsDownload: state.issue == DayNightIssue.needsDownloadNight,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.lg),
          PrismGroup(
            children: <Widget>[
              PrismRow(
                icon: Icons.light_mode_outlined,
                title: l10n.dayNightDayStarts,
                value: dayTime,
                onTap: () => unawaited(_pickStart(context, bloc, times, DayNightSlot.day)),
              ),
              PrismRow(
                icon: Icons.dark_mode_outlined,
                title: l10n.dayNightNightStarts,
                value: nightTime,
                onTap: () => unawaited(_pickStart(context, bloc, times, DayNightSlot.night)),
              ),
            ],
          ),
          if (state.issue == DayNightIssue.timesEqual)
            Padding(
              padding: const EdgeInsets.only(top: PrismSpace.xs),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.dayNightTimesEqual,
                  style: PrismTextStyles.caption(context).copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          PrismSectionHeader(title: l10n.wallpaperAutoRotateApplyTo),
          PrismSegmented<WallpaperTarget>(
            values: WallpaperTarget.values,
            selected: pair.target,
            labelOf: (WallpaperTarget target) => switch (target) {
              WallpaperTarget.home => l10n.wallpaperAutoRotateHomeScreen,
              WallpaperTarget.lock => l10n.wallpaperAutoRotateLockScreen,
              WallpaperTarget.both => l10n.wallpaperAutoRotateBothScreens,
            },
            onChanged: (WallpaperTarget target) => bloc.add(DayNightEvent.targetChanged(target)),
          ),
          const SizedBox(height: PrismSpace.lg),
          if (state.isPro)
            ..._proSection(context, state, bloc, canSwitch)
          else
            _ProGate(onSeePro: () => _seePro(context)),
        ],
      ),
    );
  }

  List<Widget> _proSection(BuildContext context, DayNightState state, DayNightBloc bloc, bool canSwitch) {
    final AppLocalizations l10n = context.l10n;
    final DayNightPair pair = state.pair;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return <Widget>[
      PrismGroup(
        children: <Widget>[
          PrismSwitchRow(
            title: l10n.dayNightSwitch,
            value: pair.enabled,
            onChanged: canSwitch ? (bool enabled) => bloc.add(DayNightEvent.toggled(enabled)) : null,
          ),
        ],
      ),
      if (!pair.isComplete)
        Padding(
          padding: const EdgeInsets.only(top: PrismSpace.xs),
          child: Text(l10n.dayNightNeedsBoth, style: PrismTextStyles.caption(context)),
        ),
      if (state.preparing)
        Padding(
          padding: const EdgeInsets.only(top: PrismSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.dayNightPreparing, style: PrismTextStyles.caption(context)),
              const SizedBox(height: PrismSpace.xs),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      if (state.issue == DayNightIssue.offlineCopyFailed) ...<Widget>[
        Padding(
          padding: const EdgeInsets.only(top: PrismSpace.sm),
          child: Text(l10n.dayNightPrepareFailed, style: PrismTextStyles.caption(context).copyWith(color: cs.error)),
        ),
        const SizedBox(height: PrismSpace.xs),
        PrismButton(
          label: l10n.dayNightTryAgain,
          variant: PrismButtonVariant.tonal,
          size: PrismButtonSize.compact,
          onPressed: () => bloc.add(const DayNightEvent.retryPressed()),
        ),
      ],
      const SizedBox(height: PrismSpace.md),
      PrismButton(
        label: l10n.dayNightSetUpAction,
        icon: Icons.auto_awesome_rounded,
        expand: true,
        onPressed: pair.enabled ? () => unawaited(showDayNightGuideSheet(context, pair: pair)) : null,
      ),
    ];
  }

  Future<void> _pickStart(BuildContext context, DayNightBloc bloc, DayNightTimes times, DayNightSlot slot) async {
    final DayTime current = times.startOf(slot);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      initialEntryMode: MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? TimePickerEntryMode.inputOnly
          : TimePickerEntryMode.dial,
    );
    if (picked == null || !context.mounted) return;
    final DayTime next = DayTime.hm(picked.hour, picked.minute);
    bloc.add(
      DayNightEvent.timesChanged(
        dayStart: slot == DayNightSlot.day ? next : times.dayStart,
        nightStart: slot == DayNightSlot.night ? next : times.nightStart,
      ),
    );
  }

  void _seePro(BuildContext context) {
    if (!app_state.prismUser.loggedIn) {
      googleSignInPopUp(context, () => _presentPaywall(context));
    } else {
      _presentPaywall(context);
    }
  }

  Future<void> _presentPaywall(BuildContext context) async {
    await PaywallOrchestrator.instance.present(placement: PaywallPlacement.autoRotate, source: 'day_night_screen');
  }
}

class _ProGate extends StatelessWidget {
  const _ProGate({required this.onSeePro});

  final VoidCallback onSeePro;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: PrismSpace.xl),
      child: PrismCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.dayNightProTitle, style: PrismTextStyles.cardTitle(context)),
            const SizedBox(height: PrismSpace.xxs),
            Text(l10n.wallpaperAutoRotateProBody, style: PrismTextStyles.body(context)),
            const SizedBox(height: PrismSpace.md),
            PrismButton(label: l10n.wallpaperSeePrismPro, expand: true, onPressed: onSeePro),
          ],
        ),
      ),
    );
  }
}
