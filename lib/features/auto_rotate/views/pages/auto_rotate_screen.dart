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
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

const Map<int, String> _intervalLabels = <int, String>{
  60: 'Every hour',
  360: 'Every 6 hours',
  720: 'Every 12 hours',
  1440: 'Every day',
};

const Map<WallpaperTarget, String> _targetLabels = <WallpaperTarget, String>{
  WallpaperTarget.home: 'Home screen',
  WallpaperTarget.lock: 'Lock screen',
  WallpaperTarget.both: 'Both',
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
                    buttonLabel: 'Try again',
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
                if (state.favouriteCount < AutoRotateBloc.minWallpapers) return const _EmptyState();
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return _Message(
      kind: GlintStateKind.empty,
      text: 'Favourite at least 2 wallpapers to rotate them.',
      buttonLabel: 'Open favourites',
      onPressed: () => context.router.push(const FavouriteWallpaperRoute()),
    );
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxxl),
      children: <Widget>[
        PrismGroup(
          children: <Widget>[
            PrismSwitchRow(
              icon: Icons.autorenew_rounded,
              title: 'Auto-rotate wallpapers',
              subtitle: '${state.favouriteCount} favourites in the mix',
              value: config.enabled,
              onChanged: (value) => bloc.add(AutoRotateEvent.toggled(value)),
            ),
          ],
        ),
        section(
          'Change',
          chips(_intervalLabels, config.intervalMinutes, (v) => bloc.add(AutoRotateEvent.intervalChanged(v))),
        ),
        section('Apply to', chips(_targetLabels, config.target, (v) => bloc.add(AutoRotateEvent.targetChanged(v)))),
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
          ],
        ),
        section(
          'Status',
          PrismGroup(
            children: <Widget>[PrismRow(icon: Icons.schedule_rounded, title: _statusText())],
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
