import 'dart:async';

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

const Map<int, String> _intervalLabels = <int, String>{
  15: 'Every 15 min (battery heavy)',
  30: 'Every 30 min',
  60: 'Every hour',
  180: 'Every 3 hours',
  360: 'Every 6 hours',
  720: 'Every 12 hours',
  1440: 'Every day',
  4320: 'Every 3 days',
  10080: 'Every week',
};

const Map<WallpaperTarget, String> _targetLabels = <WallpaperTarget, String>{
  WallpaperTarget.home: 'Home screen',
  WallpaperTarget.lock: 'Lock screen',
  WallpaperTarget.both: 'Both',
};

const Map<AutoRotateSource, String> _sourceLabels = <AutoRotateSource, String>{
  AutoRotateSource.favourites: 'Favourites',
  AutoRotateSource.downloads: 'Downloads',
  AutoRotateSource.category: 'Category',
  AutoRotateSource.wallOfTheDay: 'Wall of the Day',
  AutoRotateSource.history: 'History',
};

const String _batteryTipSteps = 'Open Settings, then Apps, Prism, Battery. Set battery use to Unrestricted.';

String _sourceNoun(AutoRotateConfig config) => switch (config.source) {
  AutoRotateSource.favourites => 'favourites',
  AutoRotateSource.downloads => 'downloads',
  AutoRotateSource.category => '${config.categoryName} wallpapers',
  AutoRotateSource.wallOfTheDay => 'Wall of the Day picks',
  AutoRotateSource.history => 'wallpapers from your history',
};

String _tooFewText(AutoRotateSource source) => switch (source) {
  AutoRotateSource.favourites => 'Favourite at least 2 wallpapers to rotate them.',
  AutoRotateSource.downloads => 'Download at least 2 wallpapers to rotate them.',
  AutoRotateSource.category => 'This category has fewer than 2 wallpapers. Pick another one.',
  AutoRotateSource.wallOfTheDay => 'There are not enough past picks yet.',
  AutoRotateSource.history => 'Set at least 2 wallpapers from Prism to rotate them.',
};

List<String> _urlsOf(FavouriteWallsState state) => state.items.map((item) => item.fullUrl).toList(growable: false);

Future<void> _presentAutoRotatePaywall(BuildContext context) async {
  await PaywallOrchestrator.instance.present(placement: PaywallPlacement.autoRotate, source: 'auto_rotate_screen');
  if (!context.mounted) return;
  context.read<SessionBloc>().add(const SessionEvent.started());
}

@RoutePage()
class AutoRotateScreen extends StatefulWidget {
  const AutoRotateScreen({super.key});

  @override
  State<AutoRotateScreen> createState() => _AutoRotateScreenState();
}

class _AutoRotateScreenState extends State<AutoRotateScreen> {
  bool _initializationFailed = false;
  bool _started = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _start();
    }
  }

  Future<void> _start() async {
    if (!_isAndroid) return;
    try {
      final SessionBloc sessionBloc = context.read<SessionBloc>();
      if (sessionBloc.state.status == LoadStatus.initial || sessionBloc.state.status == LoadStatus.loading) {
        await sessionBloc.stream.firstWhere(
          (state) => state.status != LoadStatus.initial && state.status != LoadStatus.loading,
        );
      }
      if (!mounted) return;
      if (sessionBloc.state.status != LoadStatus.success) {
        setState(() => _initializationFailed = true);
        return;
      }
      final session = sessionBloc.state.session;
      await context.favouriteWallsAdapter(listen: false).getDataBase();
      if (!mounted) return;
      final latestSession = sessionBloc.state;
      if (latestSession.status != LoadStatus.success || latestSession.session.userId != session.userId) {
        setState(() => _initializationFailed = true);
        return;
      }
      final FavouriteWallsBloc favouritesBloc = context.read<FavouriteWallsBloc>();
      if (favouritesBloc.state.status == LoadStatus.loading) {
        await favouritesBloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
        if (!mounted) return;
      }
      final latestSessionAfterLoad = sessionBloc.state;
      if (latestSessionAfterLoad.status != LoadStatus.success ||
          latestSessionAfterLoad.session.userId != session.userId) {
        setState(() => _initializationFailed = true);
        return;
      }
      final FavouriteWallsState favourites = favouritesBloc.state;
      if (favourites.status == LoadStatus.failure ||
          (session.userId.isNotEmpty &&
              (favourites.userId != session.userId || favourites.status != LoadStatus.success)) ||
          (session.userId.isEmpty && favourites.userId.isNotEmpty)) {
        setState(() => _initializationFailed = true);
        return;
      }
      setState(() => _initializationFailed = false);
      context.read<AutoRotateBloc>().add(
        AutoRotateEvent.started(
          favouriteUrls: _urlsOf(favourites),
          isPro: latestSessionAfterLoad.session.loggedIn && latestSessionAfterLoad.session.premium,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _initializationFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Auto-rotate',
      body: !_isAndroid
          ? _Message(
              kind: GlintStateKind.empty,
              text: 'Auto-rotate is only available on Android.',
              buttonLabel: 'Back',
              onPressed: () {
                context.router.maybePop();
              },
            )
          : BlocBuilder<AutoRotateBloc, AutoRotateState>(
              builder: (context, state) {
                if (state.status.isRunning && !state.config.enabled) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: 'Could not stop wallpaper rotation.',
                    buttonLabel: 'Try again',
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(false)),
                  );
                }
                if (state.status.isRunning && state.config.enabled && state.status.lastError != null) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: 'Could not change wallpaper.',
                    buttonLabel: 'Change now',
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.rotateNowPressed()),
                  );
                }
                if (state.status.lastError != null) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: 'Could not update auto-rotate.',
                    buttonLabel: 'Turn off',
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(false)),
                  );
                }
                if (_initializationFailed) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: 'Could not load auto-rotate settings.',
                    buttonLabel: 'Try again',
                    onPressed: _start,
                  );
                }
                if (!state.loaded) return PrismSkeleton.rows(avatar: false);
                if (!state.isPro) return const _ProPrompt();
                if (state.startFailed) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: 'Could not start wallpaper rotation.',
                    buttonLabel: 'Try again',
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(true)),
                  );
                }
                return _Controls(state: state);
              },
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.kind, required this.text, required this.buttonLabel, required this.onPressed});

  final GlintStateKind kind;
  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlintState(kind: kind, title: text, actionLabel: buttonLabel, onAction: onPressed);
  }
}

class _ProPrompt extends StatelessWidget {
  const _ProPrompt();

  @override
  Widget build(BuildContext context) {
    return _Message(
      kind: GlintStateKind.empty,
      text: 'Auto-rotate is a Prism Pro feature.',
      buttonLabel: 'See Prism Pro',
      onPressed: () {
        if (!app_state.prismUser.loggedIn) {
          googleSignInPopUp(context, () => _presentAutoRotatePaywall(context));
        } else {
          _presentAutoRotatePaywall(context);
        }
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});

  final AutoRotateState state;

  String _statusText() {
    if (state.startFailed) return 'Could not start. Try again.';
    if (state.starting) return 'Starting';
    if (!state.config.enabled) return 'Off';
    final int next = state.status.nextRunEpochMs;
    if (!state.status.isRunning || next <= 0) return 'Scheduled';
    return 'Next change around ${DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(next))}';
  }

  @override
  Widget build(BuildContext context) {
    final AutoRotateBloc bloc = context.read<AutoRotateBloc>();
    final AutoRotateConfig config = state.config;

    Widget section(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PrismSectionHeader(
          title: title,
          small: true,
          padding: const EdgeInsets.fromLTRB(PrismSpace.xs, PrismSpace.xl, 0, PrismSpace.xs),
        ),
        child,
      ],
    );

    Widget chips<T>(Map<T, String> labels, T selected, ValueChanged<T> onSelected) => Wrap(
      spacing: PrismSpace.xs,
      runSpacing: PrismSpace.xs,
      children: <Widget>[
        for (final MapEntry<T, String> entry in labels.entries)
          PrismChip(label: entry.value, selected: entry.key == selected, onTap: () => onSelected(entry.key)),
      ],
    );

    final bool tooFew = state.sourceCount < AutoRotateBloc.minWallpapers;
    final bool canToggle = !state.starting && (config.enabled || !tooFew);
    final AutoRotateStatus status = state.status;
    final bool caching = config.enabled && status.isRunning && status.totalCount > 0;
    final int cached = status.cachedCount.clamp(0, status.totalCount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxxl),
      children: <Widget>[
        PrismGroup(
          children: <Widget>[
            PrismSwitchRow(
              icon: Icons.autorenew_rounded,
              title: 'Auto-rotate wallpapers',
              subtitle: state.loadingSource
                  ? 'Loading wallpapers'
                  : '${state.sourceCount} ${_sourceNoun(config)} in the mix'
                        '${state.sourcesCapped ? '. Using your first 100.' : ''}',
              value: config.enabled || state.starting,
              onChanged: canToggle ? (value) => bloc.add(AutoRotateEvent.toggled(value)) : null,
            ),
          ],
        ),
        if (state.starting)
          _ProgressRow(label: 'Preparing ${state.sourceCount} wallpapers')
        else if (caching && cached < status.totalCount)
          _ProgressRow(
            label: 'Downloaded $cached of ${status.totalCount} wallpapers',
            value: cached / status.totalCount,
          ),
        if (state.sourceLoadFailed)
          Padding(
            padding: const EdgeInsets.only(top: PrismSpace.sm),
            child: _Notice(
              text: 'Could not load wallpapers. Check your connection.',
              actions: <Widget>[
                PrismButton(
                  label: 'Try again',
                  variant: PrismButtonVariant.tonal,
                  size: PrismButtonSize.compact,
                  onPressed: () => bloc.add(const AutoRotateEvent.toggled(true)),
                ),
              ],
            ),
          )
        else if (tooFew && !config.enabled && !state.loadingSource)
          Padding(
            padding: const EdgeInsets.only(top: PrismSpace.sm),
            child: _Notice(
              text: _tooFewText(config.source),
              actions: <Widget>[
                switch (config.source) {
                  AutoRotateSource.favourites => PrismButton(
                    label: 'Open favourites',
                    variant: PrismButtonVariant.tonal,
                    size: PrismButtonSize.compact,
                    onPressed: () => context.router.push(const FavouriteWallpaperRoute()),
                  ),
                  AutoRotateSource.downloads => PrismButton(
                    label: 'Open downloads',
                    variant: PrismButtonVariant.tonal,
                    size: PrismButtonSize.compact,
                    onPressed: () => context.router.push(const DownloadRoute()),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ],
            ),
          ),
        if (state.showBatteryTip)
          section(
            'Keep it running',
            _Notice(
              text:
                  'If wallpapers stop changing, set battery use for Prism to Unrestricted. '
                  'Open settings, then Apps, Prism, Battery.',
              actions: <Widget>[
                PrismButton(
                  label: 'Copy steps',
                  variant: PrismButtonVariant.tonal,
                  size: PrismButtonSize.compact,
                  onPressed: () {
                    unawaited(Clipboard.setData(const ClipboardData(text: _batteryTipSteps)));
                    toasts.info('Steps copied.');
                  },
                ),
                PrismButton(
                  label: 'Got it',
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: () => bloc.add(const AutoRotateEvent.batteryTipDismissed()),
                ),
              ],
            ),
          ),
        section(
          'Source',
          chips(
            <AutoRotateSource, String>{
              ..._sourceLabels,
              AutoRotateSource.category: config.source == AutoRotateSource.category
                  ? 'Category: ${config.categoryName}'
                  : 'Category',
            },
            config.source,
            (v) => v == AutoRotateSource.category
                ? _pickCategory(context, config.categoryName)
                : bloc.add(AutoRotateEvent.sourceChanged(v)),
          ),
        ),
        section(
          'Change',
          chips(_intervalLabels, config.intervalMinutes, (v) => bloc.add(AutoRotateEvent.intervalChanged(v))),
        ),
        section(
          'Apply to',
          chips(
            <WallpaperTarget, String>{
              for (final MapEntry<WallpaperTarget, String> entry in _targetLabels.entries)
                if (state.supportedTargets.contains(entry.key)) entry.key: entry.value,
            },
            config.target,
            (v) => bloc.add(AutoRotateEvent.targetChanged(v)),
          ),
        ),
        const SizedBox(height: PrismSpace.xl),
        PrismGroup(
          children: <Widget>[
            PrismSwitchRow(
              icon: Icons.shuffle_rounded,
              title: 'Shuffle',
              subtitle: 'Random order instead of one after another',
              value: config.shuffle,
              onChanged: (value) => bloc.add(AutoRotateEvent.shuffleChanged(value)),
            ),
            PrismSwitchRow(
              icon: Icons.power_rounded,
              title: 'Only while charging',
              subtitle: 'Change when plugged in, at most once per interval',
              value: config.chargingOnly,
              onChanged: (value) => bloc.add(AutoRotateEvent.chargingOnlyChanged(value)),
            ),
          ],
        ),
        section(
          'Status',
          PrismGroup(
            children: <Widget>[
              PrismRow(icon: Icons.schedule_rounded, title: _statusText()),
              if (caching && cached >= status.totalCount)
                PrismRow(
                  icon: Icons.check_circle_outline_rounded,
                  title: '$cached of ${status.totalCount} wallpapers ready',
                ),
            ],
          ),
        ),
        const SizedBox(height: PrismSpace.sm),
        PrismButton(
          label: 'Change now',
          icon: Icons.skip_next_rounded,
          variant: PrismButtonVariant.tonal,
          expand: true,
          onPressed: config.enabled ? () => bloc.add(const AutoRotateEvent.rotateNowPressed()) : null,
        ),
      ],
    );
  }
}

Future<void> _pickCategory(BuildContext context, String current) async {
  final AutoRotateBloc bloc = context.read<AutoRotateBloc>();
  final String? picked = await showPrismSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => PrismSheetBody(
      title: 'Pick a category',
      scrollable: true,
      child: PrismGroup(
        children: <Widget>[
          for (final String name in autoRotateCategories)
            PrismRow(
              title: name,
              showChevron: false,
              trailing: name == current ? const Icon(Icons.check_rounded, size: 20) : null,
              onTap: () => Navigator.of(sheetContext).pop(name),
            ),
        ],
      ),
    ),
  );
  if (picked != null) bloc.add(AutoRotateEvent.categoryChanged(picked));
}

/// A short message in a card, with optional actions under it.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.actions = const <Widget>[]});

  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text, style: PrismTextStyles.body(context)),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            Wrap(spacing: PrismSpace.xs, runSpacing: PrismSpace.xs, children: actions),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.xs, PrismSpace.sm, PrismSpace.xs, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: PrismTextStyles.caption(context)),
          const SizedBox(height: PrismSpace.xs),
          LinearProgressIndicator(
            value: value,
            color: cs.primary,
            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(PrismRadius.pill),
          ),
        ],
      ),
    );
  }
}
