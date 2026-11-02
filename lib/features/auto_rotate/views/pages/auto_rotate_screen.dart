import 'dart:async';

import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/views/auto_rotate_entitlement.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/views/widgets/folder_picker_sheet.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

String _intervalLabel(AppLocalizations l10n, int interval) => switch (interval) {
  15 => l10n.wallpaperAutoRotateInterval15,
  30 => l10n.wallpaperAutoRotateInterval30,
  60 => l10n.wallpaperAutoRotateIntervalHour,
  180 => l10n.wallpaperAutoRotateInterval3Hours,
  360 => l10n.wallpaperAutoRotateInterval6Hours,
  720 => l10n.wallpaperAutoRotateInterval12Hours,
  1440 => l10n.wallpaperAutoRotateIntervalDay,
  4320 => l10n.wallpaperAutoRotateInterval3Days,
  10080 => l10n.wallpaperAutoRotateIntervalWeek,
  _ => throw ArgumentError.value(interval, 'interval'),
};

String _targetLabel(AppLocalizations l10n, WallpaperTarget target) => switch (target) {
  WallpaperTarget.home => l10n.wallpaperAutoRotateHomeScreen,
  WallpaperTarget.lock => l10n.wallpaperAutoRotateLockScreen,
  WallpaperTarget.both => l10n.wallpaperAutoRotateBothScreens,
};

String _sourceLabel(AppLocalizations l10n, AutoRotateSource source) => switch (source) {
  AutoRotateSource.favourites => l10n.wallpaperAutoRotateSourceFavourites,
  AutoRotateSource.downloads => l10n.wallpaperAutoRotateSourceDownloads,
  AutoRotateSource.category => l10n.wallpaperAutoRotateSourceCategory,
  AutoRotateSource.wallOfTheDay => l10n.wallpaperAutoRotateSourceWotd,
  AutoRotateSource.history => l10n.wallpaperAutoRotateSourceHistory,
  AutoRotateSource.folder => l10n.wallpaperAutoRotateSourceFolder,
};

String _sourceNoun(AppLocalizations l10n, AutoRotateConfig config) => switch (config.source) {
  AutoRotateSource.favourites => l10n.wallpaperAutoRotateNounFavourites,
  AutoRotateSource.downloads => l10n.wallpaperAutoRotateNounDownloads,
  AutoRotateSource.category => l10n.wallpaperAutoRotateNounCategory(categoryDisplayName(config.categoryName, l10n)),
  AutoRotateSource.wallOfTheDay => l10n.wallpaperAutoRotateNounWotd,
  AutoRotateSource.history => l10n.wallpaperAutoRotateNounHistory,
  AutoRotateSource.folder => l10n.wallpaperAutoRotateNounFolder(config.folderName),
};

String _tooFewText(AppLocalizations l10n, AutoRotateSource source) => switch (source) {
  AutoRotateSource.favourites => l10n.wallpaperAutoRotateTooFewFavourites,
  AutoRotateSource.downloads => l10n.wallpaperAutoRotateTooFewDownloads,
  AutoRotateSource.category => l10n.wallpaperAutoRotateTooFewCategory,
  AutoRotateSource.wallOfTheDay => l10n.wallpaperAutoRotateTooFewWotd,
  AutoRotateSource.history => l10n.wallpaperAutoRotateTooFewHistory,
  AutoRotateSource.folder => l10n.wallpaperAutoRotateTooFewFolder,
};

List<String> _urlsOf(FavouriteWallsState state) => state.items.map((item) => item.fullUrl).toList(growable: false);

Future<void> _presentAutoRotatePaywall(BuildContext context) async {
  await PaywallOrchestrator.instance.present(placement: PaywallPlacement.autoRotate, source: 'auto_rotate_screen');
  if (!context.mounted) return;
  context.read<SessionBloc>().add(const SessionEvent.started());
}

@RoutePage()
class AutoRotateScreen extends StatefulWidget {
  const AutoRotateScreen({super.key, this.folderId, this.folderName});

  /// A folder to offer as the source. The user confirms it on the screen.
  final String? folderId;
  final String? folderName;

  @override
  State<AutoRotateScreen> createState() => _AutoRotateScreenState();
}

class _AutoRotateScreenState extends State<AutoRotateScreen> {
  bool _initializationFailed = false;
  bool _started = false;
  final String _offeredFolderOwnerId = app_state.prismUser.id;
  StreamSubscription<SessionState>? _sessionSubscription;
  late ({String id, String name})? _offeredFolder = widget.folderId == null || widget.folderId!.isEmpty
      ? null
      : (id: widget.folderId!, name: widget.folderName ?? '');

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionSubscription ??= context.read<SessionBloc>().stream.listen((SessionState session) {
      if (mounted &&
          session.status == LoadStatus.success &&
          session.session.userId != _offeredFolderOwnerId &&
          _offeredFolder != null) {
        setState(() => _offeredFolder = null);
      }
    });
    if (!_started) {
      _started = true;
      _start();
    }
  }

  @override
  void dispose() {
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
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
          isPro: autoRotateEntitled(latestSessionAfterLoad.session),
          passUntil: autoRotatePassEnd(latestSessionAfterLoad.session),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _initializationFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: context.l10n.wallpaperAutoRotateTitle,
      body: !_isAndroid
          ? GlintState(
              kind: GlintStateKind.empty,
              title: context.l10n.autoRotateIosTitle,
              body: context.l10n.autoRotateIosBody,
              actionLabel: context.l10n.autoRotateIosAction,
              onAction: () => context.router.replace(IosShortcutsGuideRoute(source: 'auto_rotate')),
            )
          : BlocBuilder<AutoRotateBloc, AutoRotateState>(
              builder: (context, state) {
                if (state.status.isRunning && !state.config.enabled) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: context.l10n.wallpaperAutoRotateStopError,
                    buttonLabel: context.l10n.wallpaperTryAgain,
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(false)),
                  );
                }
                if (state.status.isRunning && state.config.enabled && state.status.lastError != null) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: context.l10n.wallpaperAutoRotateChangeError,
                    buttonLabel: context.l10n.wallpaperChangeNow,
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.rotateNowPressed()),
                  );
                }
                if (state.status.lastError != null) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: context.l10n.wallpaperAutoRotateUpdateError,
                    buttonLabel: context.l10n.wallpaperTurnOff,
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(false)),
                  );
                }
                if (_initializationFailed) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: context.l10n.wallpaperAutoRotateLoadError,
                    buttonLabel: context.l10n.wallpaperTryAgain,
                    onPressed: _start,
                  );
                }
                if (!state.loaded) return PrismSkeleton.rows(avatar: false);
                if (!state.isPro) return const _ProPrompt();
                if (state.startFailed) {
                  return _Message(
                    kind: GlintStateKind.error,
                    text: context.l10n.wallpaperAutoRotateStartError,
                    buttonLabel: context.l10n.wallpaperTryAgain,
                    onPressed: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(true)),
                  );
                }
                return _Controls(
                  state: state,
                  offeredFolder: _offeredFolder,
                  onOfferClosed: () => setState(() => _offeredFolder = null),
                  onChooseFolder: (String? current) => _chooseFolder(context, current),
                  onRetrySource: () => context.read<AutoRotateBloc>().add(const AutoRotateEvent.toggled(true)),
                  onConfirmOffer: (String id, String name) => _confirmOffer(context, id, name),
                );
              },
            ),
    );
  }

  Future<void> _chooseFolder(BuildContext context, String? current) async {
    final FolderEntity? picked = await pickFolder(context, current);
    if (!context.mounted || picked == null || app_state.prismUser.id != picked.ownerId) return;
    context.read<AutoRotateBloc>().add(AutoRotateEvent.folderChosen(folderId: picked.id, name: picked.name));
  }

  void _confirmOffer(BuildContext context, String id, String name) {
    if (app_state.prismUser.id != _offeredFolderOwnerId) {
      setState(() => _offeredFolder = null);
      return;
    }
    context.read<AutoRotateBloc>().add(AutoRotateEvent.folderChosen(folderId: id, name: name, enable: true));
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

class _ProPrompt extends StatefulWidget {
  const _ProPrompt();

  @override
  State<_ProPrompt> createState() => _ProPromptState();
}

class _ProPromptState extends State<_ProPrompt> {
  bool _buying = false;

  Future<void> _buyPass() async {
    if (!app_state.prismUser.loggedIn) {
      googleSignInPopUp(context, () => unawaited(_buyPass()));
      return;
    }
    if (_buying) return;
    setState(() => _buying = true);
    final CoinMutationResult result = await CoinsService.instance.spend(
      CoinSpendAction.autoRotatePass7d,
      sourceTag: 'auto_rotate.pass',
    );
    if (!mounted) return;
    setState(() => _buying = false);
    if (result.success) {
      context.read<AutoRotateBloc>().add(
        AutoRotateEvent.entitlementChanged(
          isPro: true,
          userId: context.read<SessionBloc>().state.session.userId,
          passUntil: result.passUntil,
        ),
      );
      toasts.success(context.l10n.wallpaperAutoRotatePassEnabled);
    } else if (result.insufficientBalance) {
      toasts.error(context.l10n.wallpaperInsufficientCoins);
    } else {
      toasts.error(context.l10n.wallpaperAutoRotateUnlockError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PrismSpace.page),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Glint(),
              const SizedBox(height: PrismSpace.md),
              Text(
                context.l10n.wallpaperAutoRotateProTitle,
                textAlign: TextAlign.center,
                style: PrismTextStyles.cardTitle(context),
              ),
              const SizedBox(height: PrismSpace.xxs),
              Text(
                context.l10n.wallpaperAutoRotateProBody,
                textAlign: TextAlign.center,
                style: PrismTextStyles.body(context),
              ),
              const SizedBox(height: PrismSpace.md),
              PrismButton(
                label: context.l10n.wallpaperAutoRotatePassPurchase(CoinPolicy.autoRotatePass7d),
                expand: true,
                loading: _buying,
                onPressed: () => unawaited(_buyPass()),
              ),
              const SizedBox(height: PrismSpace.xs),
              PrismButton(
                label: context.l10n.wallpaperSeePrismPro,
                expand: true,
                variant: PrismButtonVariant.ghost,
                onPressed: () {
                  if (!app_state.prismUser.loggedIn) {
                    googleSignInPopUp(context, () => _presentAutoRotatePaywall(context));
                  } else {
                    _presentAutoRotatePaywall(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    this.offeredFolder,
    required this.onOfferClosed,
    required this.onChooseFolder,
    required this.onRetrySource,
    required this.onConfirmOffer,
  });

  final AutoRotateState state;
  final ({String id, String name})? offeredFolder;
  final VoidCallback onOfferClosed;
  final ValueChanged<String?> onChooseFolder;
  final VoidCallback onRetrySource;
  final void Function(String id, String name) onConfirmOffer;

  String _statusText(AppLocalizations l10n) {
    if (state.startFailed) return l10n.wallpaperAutoRotateCouldNotStart;
    if (state.starting) return l10n.wallpaperAutoRotateStarting;
    if (!state.config.enabled) return l10n.wallpaperAutoRotateOff;
    final int next = state.status.nextRunEpochMs;
    if (!state.status.isRunning || next <= 0) return l10n.wallpaperAutoRotateScheduled;
    final String time = DateFormat.jm(l10n.localeName).format(DateTime.fromMillisecondsSinceEpoch(next));
    return l10n.wallpaperAutoRotateNextChange(time);
  }

  /// When the 7-day pass ends. Null for Pro users and when no pass is active.
  DateTime? _passEnd() {
    if (app_state.prismUser.premium) return null;
    final Passes passes = CoinsService.instance.currentPasses;
    final DateTime? end = passes.autoRotatePassUntil;
    return end != null && passes.autoRotatePassActive(DateTime.now()) ? end : null;
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
          padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.xs, PrismSpace.xl, 0, PrismSpace.xs),
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

    final ({String id, String name})? offer = offeredFolder;
    final bool offerApplied =
        offer != null && config.source == AutoRotateSource.folder && config.folderId == offer.id && config.enabled;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxxl),
      children: <Widget>[
        if (offer != null && !offerApplied)
          Padding(
            padding: const EdgeInsets.only(bottom: PrismSpace.sm),
            child: _Notice(
              title: context.l10n.wallpaperAutoRotateConfirmFolderTitle(offer.name),
              text: context.l10n.wallpaperAutoRotateConfirmFolderBody,
              actions: <Widget>[
                PrismButton(
                  label: context.l10n.wallpaperAutoRotateConfirmFolderAction,
                  icon: Icons.autorenew_rounded,
                  size: PrismButtonSize.compact,
                  onPressed: () => onConfirmOffer(offer.id, offer.name),
                ),
                PrismButton(
                  label: context.l10n.wallpaperNotNow,
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: onOfferClosed,
                ),
              ],
            ),
          ),
        PrismGroup(
          children: <Widget>[
            PrismSwitchRow(
              icon: Icons.autorenew_rounded,
              title: context.l10n.wallpaperAutoRotateTitle,
              subtitle: state.loadingSource
                  ? context.l10n.wallpaperAutoRotateLoadingWalls
                  : state.sourcesCapped
                  ? context.l10n.wallpaperAutoRotateMixCapped(state.sourceCount, _sourceNoun(context.l10n, config))
                  : context.l10n.wallpaperAutoRotateMix(state.sourceCount, _sourceNoun(context.l10n, config)),
              value: config.enabled || state.starting,
              onChanged: canToggle ? (value) => bloc.add(AutoRotateEvent.toggled(value)) : null,
            ),
          ],
        ),
        if (_passEnd() case final DateTime end)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.xs, PrismSpace.sm, PrismSpace.xs, 0),
            child: Text(
              context.l10n.wallpaperAutoRotateEnabledUntil(
                DateFormat.MMMd(context.l10n.localeName).add_jm().format(end.toLocal()),
              ),
              style: PrismTextStyles.caption(context),
            ),
          ),
        if (state.starting)
          _ProgressRow(label: context.l10n.wallpaperAutoRotatePreparing(state.sourceCount))
        else if (caching && cached < status.totalCount)
          _ProgressRow(
            label: context.l10n.wallpaperAutoRotateDownloadedCount(cached, status.totalCount),
            value: cached / status.totalCount,
          ),
        if (state.sourceLoadFailed)
          Padding(
            padding: const EdgeInsets.only(top: PrismSpace.sm),
            child: _Notice(
              text: context.l10n.wallpaperAutoRotateSourceLoadError,
              actions: <Widget>[
                PrismButton(
                  label: context.l10n.wallpaperTryAgain,
                  variant: PrismButtonVariant.tonal,
                  size: PrismButtonSize.compact,
                  onPressed: onRetrySource,
                ),
              ],
            ),
          )
        else if (tooFew && !config.enabled && !state.loadingSource)
          Padding(
            padding: const EdgeInsets.only(top: PrismSpace.sm),
            child: _Notice(
              text: _tooFewText(context.l10n, config.source),
              actions: <Widget>[
                switch (config.source) {
                  AutoRotateSource.favourites => PrismButton(
                    label: context.l10n.wallpaperAutoRotateOpenFavourites,
                    variant: PrismButtonVariant.tonal,
                    size: PrismButtonSize.compact,
                    onPressed: () => context.router.push(const FavouriteWallpaperRoute()),
                  ),
                  AutoRotateSource.downloads => PrismButton(
                    label: context.l10n.wallpaperAutoRotateOpenDownloads,
                    variant: PrismButtonVariant.tonal,
                    size: PrismButtonSize.compact,
                    onPressed: () => context.router.push(const DownloadRoute()),
                  ),
                  AutoRotateSource.folder when config.folderId != null => PrismButton(
                    label: context.l10n.wallpaperAutoRotateOpenFolder,
                    variant: PrismButtonVariant.tonal,
                    size: PrismButtonSize.compact,
                    onPressed: () => context.router.push(FolderRoute(folderId: config.folderId!)),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ],
            ),
          ),
        if (state.showBatteryTip)
          section(
            context.l10n.wallpaperAutoRotateKeepRunning,
            _Notice(
              text: context.l10n.wallpaperAutoRotateBatteryTip,
              actions: <Widget>[
                PrismButton(
                  label: context.l10n.wallpaperAutoRotateCopySteps,
                  variant: PrismButtonVariant.tonal,
                  size: PrismButtonSize.compact,
                  onPressed: () {
                    unawaited(Clipboard.setData(ClipboardData(text: context.l10n.wallpaperAutoRotateBatterySteps)));
                    toasts.info(context.l10n.wallpaperAutoRotateStepsCopied);
                  },
                ),
                PrismButton(
                  label: context.l10n.wallpaperAutoRotateGotIt,
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: () => bloc.add(const AutoRotateEvent.batteryTipDismissed()),
                ),
              ],
            ),
          ),
        section(
          context.l10n.wallpaperAutoRotateSourceLabel,
          chips(
            <AutoRotateSource, String>{
              for (final AutoRotateSource source in AutoRotateSource.values) source: _sourceLabel(context.l10n, source),
              AutoRotateSource.category: config.source == AutoRotateSource.category
                  ? '${context.l10n.wallpaperAutoRotateSourceCategory}: ${categoryDisplayName(config.categoryName, context.l10n)}'
                  : context.l10n.wallpaperAutoRotateSourceCategory,
              if (config.source == AutoRotateSource.folder && config.folderName.isNotEmpty)
                AutoRotateSource.folder: context.l10n.wallpaperAutoRotateSourceFolderNamed(config.folderName),
            },
            config.source,
            (v) => switch (v) {
              AutoRotateSource.category => _pickCategory(context, config.categoryName),
              AutoRotateSource.folder => onChooseFolder(config.folderId),
              _ => bloc.add(AutoRotateEvent.sourceChanged(v)),
            },
          ),
        ),
        section(
          context.l10n.wallpaperAutoRotateChangeLabel,
          chips(
            <int, String>{
              for (final int interval in <int>[15, 30, 60, 180, 360, 720, 1440, 4320, 10080])
                interval: _intervalLabel(context.l10n, interval),
            },
            config.intervalMinutes,
            (v) => bloc.add(AutoRotateEvent.intervalChanged(v)),
          ),
        ),
        section(
          context.l10n.wallpaperAutoRotateApplyTo,
          chips(
            <WallpaperTarget, String>{
              for (final WallpaperTarget target in WallpaperTarget.values)
                if (state.supportedTargets.contains(target)) target: _targetLabel(context.l10n, target),
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
              title: context.l10n.wallpaperAutoRotateShuffle,
              subtitle: context.l10n.wallpaperAutoRotateShuffleDescription,
              value: config.shuffle,
              onChanged: (value) => bloc.add(AutoRotateEvent.shuffleChanged(value)),
            ),
            PrismSwitchRow(
              icon: Icons.power_rounded,
              title: context.l10n.wallpaperAutoRotateChargingOnly,
              subtitle: context.l10n.wallpaperAutoRotateChargingDescription,
              value: config.chargingOnly,
              onChanged: (value) => bloc.add(AutoRotateEvent.chargingOnlyChanged(value)),
            ),
          ],
        ),
        section(
          context.l10n.wallpaperAutoRotateStatusLabel,
          PrismGroup(
            children: <Widget>[
              PrismRow(icon: Icons.schedule_rounded, title: _statusText(context.l10n)),
              if (caching && cached >= status.totalCount)
                PrismRow(
                  icon: Icons.check_circle_outline_rounded,
                  title: context.l10n.wallpaperAutoRotateReadyCount(cached, status.totalCount),
                ),
            ],
          ),
        ),
        const SizedBox(height: PrismSpace.sm),
        PrismButton(
          label: context.l10n.wallpaperChangeNow,
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
    context,
    builder: (sheetContext) => PrismSheetBody(
      title: context.l10n.wallpaperAutoRotatePickCategory,
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
  const _Notice({required this.text, this.title, this.actions = const <Widget>[]});

  final String? title;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title case final String title) ...<Widget>[
            Text(title, style: PrismTextStyles.cardTitle(context)),
            const SizedBox(height: PrismSpace.xxs),
          ],
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
      padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.xs, PrismSpace.sm, PrismSpace.xs, 0),
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
