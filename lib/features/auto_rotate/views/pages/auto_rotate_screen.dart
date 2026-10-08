import 'dart:async';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

const String _fontFamily = 'Proxima Nova';

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
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: 'Auto-rotate'),
      ),
      body: !_isAndroid
          ? _Message(
              icon: Icons.android_rounded,
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
                    icon: Icons.error_outline_rounded,
                    text: 'Could not stop wallpaper rotation.',
                    buttonLabel: 'Try again',
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(false)),
                  );
                }
                if (state.status.isRunning && state.config.enabled && state.status.lastError != null) {
                  return _Message(
                    icon: Icons.error_outline_rounded,
                    text: 'Could not change wallpaper.',
                    buttonLabel: 'Change now',
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.rotateNowPressed()),
                  );
                }
                if (state.status.lastError != null) {
                  return _Message(
                    icon: Icons.error_outline_rounded,
                    text: 'Could not update auto-rotate.',
                    buttonLabel: 'Turn off',
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(false)),
                  );
                }
                if (_initializationFailed) {
                  return _Message(
                    icon: Icons.error_outline_rounded,
                    text: 'Could not load auto-rotate settings.',
                    buttonLabel: 'Try again',
                    onPressed: _start,
                  );
                }
                if (!state.loaded) return const Center(child: CircularProgressIndicator());
                if (!state.isPro) return const _ProPrompt();
                if (state.startFailed) {
                  return _Message(
                    icon: Icons.error_outline_rounded,
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
  const _Message({required this.icon, required this.text, required this.buttonLabel, required this.onPressed});

  final IconData icon;
  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.secondary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.secondary, fontFamily: _fontFamily, fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

class _ProPrompt extends StatelessWidget {
  const _ProPrompt();

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.autorenew_rounded,
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
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.error;
    final TextStyle titleStyle = TextStyle(
      color: theme.colorScheme.secondary,
      fontWeight: FontWeight.w500,
      fontFamily: _fontFamily,
    );
    const TextStyle subtitleStyle = TextStyle(fontSize: 12);
    final AutoRotateConfig config = state.config;

    Widget card(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        color: theme.cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: accent,
                    fontFamily: _fontFamily,
                  ),
                ),
              ),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    Widget chips<T>(Map<T, String> labels, T selected, ValueChanged<T> onSelected) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final MapEntry<T, String> entry in labels.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: entry.key == selected,
              selectedColor: accent,
              labelStyle: TextStyle(
                color: entry.key == selected ? theme.colorScheme.onError : theme.colorScheme.secondary,
                fontFamily: _fontFamily,
                fontWeight: entry.key == selected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) {
                PrismHaptics.selection();
                onSelected(entry.key);
              },
            ),
        ],
      ),
    );

    final bool tooFew = state.sourceCount < AutoRotateBloc.minWallpapers;
    final bool canToggle = !state.starting && (config.enabled || !tooFew);
    final AutoRotateStatus status = state.status;
    final bool caching = config.enabled && status.isRunning && status.totalCount > 0;
    final int cached = status.cachedCount.clamp(0, status.totalCount);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        card('', [
          SwitchListTile(
            activeThumbColor: accent,
            secondary: const Icon(Icons.autorenew_rounded),
            value: config.enabled || state.starting,
            title: Text('Auto-rotate wallpapers', style: titleStyle),
            subtitle: Text(
              state.loadingSource
                  ? 'Loading wallpapers'
                  : '${state.sourceCount} ${_sourceNoun(config)} in the mix'
                        '${state.sourcesCapped ? '. Using your first 100.' : ''}',
              style: subtitleStyle,
            ),
            onChanged: canToggle
                ? (value) {
                    PrismHaptics.selection();
                    bloc.add(AutoRotateEvent.toggled(value));
                  }
                : null,
          ),
          if (state.starting)
            _ProgressRow(label: 'Preparing ${state.sourceCount} wallpapers', color: accent)
          else if (caching && cached < status.totalCount)
            _ProgressRow(
              label: 'Downloaded $cached of ${status.totalCount} wallpapers',
              value: cached / status.totalCount,
              color: accent,
            ),
          if (state.sourceLoadFailed)
            ListTile(
              title: const Text('Could not load wallpapers. Check your connection.', style: subtitleStyle),
              trailing: TextButton(
                onPressed: () => bloc.add(const AutoRotateEvent.toggled(true)),
                child: const Text('Try again'),
              ),
            )
          else if (tooFew && !config.enabled && !state.loadingSource)
            ListTile(
              title: Text(_tooFewText(config.source), style: subtitleStyle),
              trailing: switch (config.source) {
                AutoRotateSource.favourites => TextButton(
                  onPressed: () => context.router.push(const FavouriteWallpaperRoute()),
                  child: const Text('Open favourites'),
                ),
                AutoRotateSource.downloads => TextButton(
                  onPressed: () => context.router.push(const DownloadRoute()),
                  child: const Text('Open downloads'),
                ),
                _ => null,
              },
            ),
        ]),
        if (state.showBatteryTip)
          card('KEEP IT RUNNING', [
            ListTile(
              title: const Text(
                'If wallpapers stop changing, set battery use for Prism to Unrestricted. '
                'Open settings, then Apps, Prism, Battery.',
                style: subtitleStyle,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      unawaited(Clipboard.setData(const ClipboardData(text: _batteryTipSteps)));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Steps copied.'), duration: Duration(seconds: 2)));
                    },
                    child: const Text('Copy steps'),
                  ),
                  TextButton(
                    onPressed: () => bloc.add(const AutoRotateEvent.batteryTipDismissed()),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ]),
        card('SOURCE', [
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
        ]),
        card('CHANGE', [
          chips(_intervalLabels, config.intervalMinutes, (v) => bloc.add(AutoRotateEvent.intervalChanged(v))),
        ]),
        card('APPLY TO', [
          chips(
            <WallpaperTarget, String>{
              for (final MapEntry<WallpaperTarget, String> entry in _targetLabels.entries)
                if (state.supportedTargets.contains(entry.key)) entry.key: entry.value,
            },
            config.target,
            (v) => bloc.add(AutoRotateEvent.targetChanged(v)),
          ),
        ]),
        card('', [
          SwitchListTile(
            activeThumbColor: accent,
            secondary: const Icon(Icons.shuffle_rounded),
            value: config.shuffle,
            title: Text('Shuffle', style: titleStyle),
            subtitle: const Text('Random order instead of one after another', style: subtitleStyle),
            onChanged: (value) {
              PrismHaptics.selection();
              bloc.add(AutoRotateEvent.shuffleChanged(value));
            },
          ),
        ]),
        card('', [
          SwitchListTile(
            activeThumbColor: accent,
            secondary: const Icon(Icons.power_rounded),
            value: config.chargingOnly,
            title: Text('Only while charging', style: titleStyle),
            subtitle: const Text('Change when plugged in, at most once per interval', style: subtitleStyle),
            onChanged: (value) {
              PrismHaptics.selection();
              bloc.add(AutoRotateEvent.chargingOnlyChanged(value));
            },
          ),
        ]),
        card('STATUS', [
          ListTile(title: Text(_statusText(), style: titleStyle)),
          if (caching && cached >= status.totalCount)
            ListTile(title: Text('$cached of ${status.totalCount} wallpapers ready', style: subtitleStyle)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: config.enabled
                  ? () {
                      PrismHaptics.tap();
                      bloc.add(const AutoRotateEvent.rotateNowPressed());
                    }
                  : null,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Change now'),
            ),
          ),
        ]),
      ],
    );
  }
}

Future<void> _pickCategory(BuildContext context, String current) async {
  final AutoRotateBloc bloc = context.read<AutoRotateBloc>();
  final String? picked = await showPrismSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _CategorySheet(current: current),
  );
  if (picked != null) bloc.add(AutoRotateEvent.categoryChanged(picked));
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Pick a category',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final String name in autoRotateCategories)
                    ListTile(
                      title: Text(name),
                      selected: name == current,
                      trailing: name == current ? const Icon(Icons.check_rounded) : null,
                      onTap: () => Navigator.of(context).pop(name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.color, this.value});

  final String label;
  final Color color;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: value, color: color, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }
}
