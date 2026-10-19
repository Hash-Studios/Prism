import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_style_picker.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_style_preview.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

enum _LiveMode { photo, gradients, video }

enum _UnlockChoice { coins, pro }

String _liveModeLabel(AppLocalizations l10n, _LiveMode mode) => switch (mode) {
  _LiveMode.photo => l10n.wallpaperLiveModePhoto,
  _LiveMode.gradients => l10n.wallpaperLiveModeGradients,
  _LiveMode.video => l10n.wallpaperLiveModeVideo,
};

String _liveOutcomeMessage(AppLocalizations l10n, LiveApplyOutcome outcome) => switch (outcome.status) {
  LiveApplyStatus.applied => l10n.wallpaperLiveApplied,
  LiveApplyStatus.confirmInPreview => l10n.wallpaperLiveConfirmPreview,
  LiveApplyStatus.cancelled => '',
  LiveApplyStatus.unsupported => l10n.wallpaperLiveUnsupported,
  LiveApplyStatus.proRequired => l10n.wallpaperLiveProStyleRequired,
  LiveApplyStatus.failed => switch (outcome.failure) {
    LiveApplyFailure.setFailed || null => l10n.wallpaperLiveErrorGeneric,
    LiveApplyFailure.keepPrismOpen => l10n.wallpaperLiveKeepPrismOpen,
    LiveApplyFailure.textureDownloadFailed => l10n.wallpaperLiveTextureDownloadFailed,
    LiveApplyFailure.texturePreparationFailed => l10n.wallpaperLiveTexturePrepareFailed,
    LiveApplyFailure.textureTooDetailed => l10n.wallpaperLiveTextureTooDetailed,
    LiveApplyFailure.videoReadFailed => l10n.wallpaperLiveVideoReadFailed,
    LiveApplyFailure.videoTooLarge => l10n.wallpaperLiveVideoTooLarge,
    LiveApplyFailure.fileTooLarge => l10n.wallpaperLiveErrorTooLarge,
    LiveApplyFailure.imageTooLarge || LiveApplyFailure.imageTooLargeForDevice => l10n.wallpaperLiveErrorImageTooLarge,
    LiveApplyFailure.wallpaperNotAllowed => l10n.wallpaperLiveErrorNotAllowed,
    LiveApplyFailure.outOfMemory => l10n.wallpaperLiveErrorMemory,
    LiveApplyFailure.timeout => l10n.wallpaperLiveErrorTimeout,
    LiveApplyFailure.invalidVideo => l10n.wallpaperLiveErrorVideo,
    LiveApplyFailure.sourceUnavailable => l10n.wallpaperLiveErrorReadFile,
    LiveApplyFailure.permissionDenied => l10n.wallpaperLiveErrorPermission,
    LiveApplyFailure.styleUnavailable => l10n.wallpaperLiveErrorStyle,
    LiveApplyFailure.systemPreviewUnavailable => l10n.wallpaperLiveErrorPreview,
  },
};

String _motionStyleLabel(AppLocalizations l10n, MotionStyle style) => switch (style) {
  MotionStyle.drift => l10n.wallpaperLiveStyleDrift,
  MotionStyle.breathe => l10n.wallpaperLiveStyleBreathe,
  MotionStyle.ripple => l10n.wallpaperLiveStyleRipple,
  MotionStyle.shimmer => l10n.wallpaperLiveStyleShimmer,
};

String _motionStyleDescription(AppLocalizations l10n, MotionStyle style) => switch (style) {
  MotionStyle.drift => l10n.wallpaperLiveStyleDriftDescription,
  MotionStyle.breathe => l10n.wallpaperLiveStyleBreatheDescription,
  MotionStyle.ripple => l10n.wallpaperLiveStyleRippleDescription,
  MotionStyle.shimmer => l10n.wallpaperLiveStyleShimmerDescription,
};

String _gradientStyleLabel(AppLocalizations l10n, GradientStyle style) => switch (style) {
  GradientStyle.aurora => l10n.wallpaperLiveStyleAurora,
  GradientStyle.mesh => l10n.wallpaperLiveStyleMesh,
  GradientStyle.waves => l10n.wallpaperLiveStyleWaves,
  GradientStyle.plasma => l10n.wallpaperLiveStylePlasma,
  GradientStyle.starfield => l10n.wallpaperLiveStyleStarfield,
};

String _gradientStyleDescription(AppLocalizations l10n, GradientStyle style) => switch (style) {
  GradientStyle.aurora => l10n.wallpaperLiveStyleAuroraDescription,
  GradientStyle.mesh => l10n.wallpaperLiveStyleMeshDescription,
  GradientStyle.waves => l10n.wallpaperLiveStyleWavesDescription,
  GradientStyle.plasma => l10n.wallpaperLiveStylePlasmaDescription,
  GradientStyle.starfield => l10n.wallpaperLiveStyleStarfieldDescription,
};

/// The paid styles the signed-in user unlocked with coins, each with the end of its unlock.
Map<String, DateTime> liveStyleUnlocks() => CoinsService.instance.currentPasses.liveStyles;

typedef VideoPicker = Future<String?> Function();

Future<String?> _pickVideoFromGallery() async {
  final XFile? file = await ImagePicker().pickVideo(source: ImageSource.gallery);
  return file?.path;
}

class LiveWallpaperView extends StatefulWidget {
  const LiveWallpaperView({super.key, this.imageUrl, this.accentSeed, this.pickVideo = _pickVideoFromGallery});

  final String? imageUrl;

  /// The dominant colour of the wallpaper the user came from. Null means the app accent.
  final Color? accentSeed;
  final VideoPicker pickVideo;

  @override
  State<LiveWallpaperView> createState() => _LiveWallpaperViewState();
}

class _LiveWallpaperViewState extends State<LiveWallpaperView> with WidgetsBindingObserver {
  late _LiveMode _mode = widget.imageUrl == null ? _LiveMode.gradients : _LiveMode.photo;
  int _seedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// An unlock may have ended, or been bought on another device, while the app was away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<LiveWallpaperBloc>()
      ..add(LiveWallpaperEvent.proChanged(app_state.prismUser.premium))
      ..add(LiveWallpaperEvent.unlockedStylesChanged(liveStyleUnlocks()));
  }

  List<_LiveMode> get _modes => <_LiveMode>[
    if (widget.imageUrl != null) _LiveMode.photo,
    _LiveMode.gradients,
    _LiveMode.video,
  ];

  List<Color> _seeds(BuildContext context) =>
      LivePalette.seedVariants(widget.accentSeed ?? Theme.of(context).colorScheme.primary);

  LivePalette _palette(BuildContext context) {
    return LivePalette.fromAccent(_seeds(context)[_seedIndex], dark: Theme.of(context).brightness == Brightness.dark);
  }

  Future<void> _onOutcome(BuildContext context, LiveApplyOutcome outcome) async {
    final LiveWallpaperBloc bloc = context.read<LiveWallpaperBloc>()..add(const LiveWallpaperEvent.outcomeHandled());
    switch (outcome.status) {
      case LiveApplyStatus.cancelled:
        return;
      case LiveApplyStatus.proRequired:
        await _offerUnlock(bloc);
        return;
      case LiveApplyStatus.applied:
      case LiveApplyStatus.confirmInPreview:
      case LiveApplyStatus.failed:
      case LiveApplyStatus.unsupported:
        final ColorScheme scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _liveOutcomeMessage(context.l10n, outcome),
                style: TextStyle(color: outcome.isError ? scheme.onError : null),
              ),
              backgroundColor: outcome.isError ? scheme.error : null,
            ),
          );
    }
  }

  /// The style the user tried to apply: its id, its name and its price are what the unlock sheet shows.
  (String id, String label) get _lockedStyle {
    final LiveWallpaperState state = context.read<LiveWallpaperBloc>().state;
    return _mode == _LiveMode.photo
        ? (state.motionStyle.name, _motionStyleLabel(context.l10n, state.motionStyle))
        : (state.gradientStyle.name, _gradientStyleLabel(context.l10n, state.gradientStyle));
  }

  Future<void> _offerUnlock(LiveWallpaperBloc bloc) async {
    final (String id, String label) = _lockedStyle;
    final _UnlockChoice? choice = await showPrismSheet<_UnlockChoice>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => PrismSheetBody(
        title: context.l10n.wallpaperLiveUnlockStyleTitle(label),
        message: context.l10n.wallpaperLiveUnlockStyleBody,
        actions: <Widget>[
          PrismButton(
            label: context.l10n.wallpaperLiveUnlockStyleAction(
              label,
              NumberFormat.decimalPattern(context.l10n.localeName).format(CoinPolicy.liveWallpaperStyle),
            ),
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(_UnlockChoice.coins),
          ),
          PrismButton(
            label: context.l10n.wallpaperSeePrismPro,
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: () => Navigator.of(sheetContext).pop(_UnlockChoice.pro),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _UnlockChoice.coins:
        if (!app_state.prismUser.loggedIn) {
          googleSignInPopUp(context, () {});
          return;
        }
        final CoinMutationResult result = await CoinsService.instance.spend(
          CoinSpendAction.liveWallpaperStyle,
          styleId: id,
          sourceTag: 'live_wallpaper.style',
        );
        if (!mounted) return;
        if (result.success) {
          bloc.add(LiveWallpaperEvent.unlockedStylesChanged(liveStyleUnlocks()));
          toasts.success(context.l10n.wallpaperLiveStyleUnlocked(label));
        } else if (result.insufficientBalance) {
          toasts.error(context.l10n.wallpaperInsufficientCoins);
        } else {
          toasts.error(context.l10n.wallpaperLiveUnlockError(label));
        }
      case _UnlockChoice.pro:
        await PaywallOrchestrator.instance.presentOrRequireSignIn(
          context,
          placement: PaywallPlacement.mainUpsell,
          source: 'live_wallpaper_screen',
        );
        bloc.add(LiveWallpaperEvent.proChanged(app_state.prismUser.premium));
    }
  }

  Future<void> _chooseVideo(BuildContext context) async {
    final LiveWallpaperBloc bloc = context.read<LiveWallpaperBloc>();
    String? path;
    try {
      path = await widget.pickVideo();
    } catch (_) {
      path = null;
    }
    if (path != null) bloc.add(LiveWallpaperEvent.videoPicked(path));
  }

  void _apply(BuildContext context) {
    final LiveWallpaperBloc bloc = context.read<LiveWallpaperBloc>();
    PrismHaptics.tap();
    switch (_mode) {
      case _LiveMode.photo:
        final Size size = MediaQuery.sizeOf(context);
        bloc.add(
          LiveWallpaperEvent.motionApplied(palette: _palette(context), screenAspectRatio: size.width / size.height),
        );
      case _LiveMode.gradients:
        bloc.add(LiveWallpaperEvent.gradientApplied(palette: _palette(context)));
      case _LiveMode.video:
        bloc.add(const LiveWallpaperEvent.videoApplied());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: context.l10n.wallpaperLiveTitle,
      body: BlocConsumer<LiveWallpaperBloc, LiveWallpaperState>(
        listenWhen: (previous, current) => current.outcome != null && previous.outcome != current.outcome,
        listener: (context, state) => _onOutcome(context, state.outcome!),
        builder: (context, state) {
          switch (state.status) {
            case LiveWallpaperStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case LiveWallpaperStatus.unsupported:
              return GlintState(
                kind: GlintStateKind.empty,
                title: context.l10n.wallpaperLiveUnavailableTitle,
                body: context.l10n.wallpaperLiveUnavailableBody,
                actionLabel: context.l10n.wallpaperBack,
                onAction: () => Navigator.of(context).maybePop(),
              );
            case LiveWallpaperStatus.ready:
              return _buildReady(context, state);
          }
        },
      ),
    );
  }

  Widget _buildReady(BuildContext context, LiveWallpaperState state) {
    final List<_LiveMode> modes = _modes;
    final bool shadersOff = !state.capabilities.supportsShaders && _mode != _LiveMode.video;
    final bool videoOff = !state.capabilities.supportsVideo && _mode == _LiveMode.video;
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final _LiveMode mode in modes)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_liveModeLabel(context.l10n, mode)),
                    selected: mode == _mode,
                    onSelected: (_) {
                      PrismHaptics.selection();
                      setState(() => _mode = mode);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: shadersOff || videoOff
              ? GlintState(
                  kind: GlintStateKind.empty,
                  title: context.l10n.wallpaperLiveDeviceUnavailable,
                  body: videoOff
                      ? context.l10n.wallpaperLiveVideoUnsupported
                      : context.l10n.wallpaperLiveShaderUnsupported,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: switch (_mode) {
                    _LiveMode.photo => _PhotoSection(imageUrl: widget.imageUrl!, state: state),
                    _LiveMode.gradients => _GradientSection(
                      state: state,
                      palette: _palette(context),
                      seeds: _seeds(context),
                      seedIndex: _seedIndex,
                      onSeedSelected: (index) {
                        PrismHaptics.selection();
                        setState(() => _seedIndex = index);
                      },
                    ),
                    _LiveMode.video => _VideoSection(state: state, onChoose: () => _chooseVideo(context)),
                  },
                ),
        ),
        if (!(shadersOff || videoOff))
          _ApplyBar(
            label: _applyLabel(state),
            busy: state.applying,
            enabled: _mode != _LiveMode.video || state.videoPath != null,
            onPressed: () => _apply(context),
          ),
      ],
    );
  }

  String _applyLabel(LiveWallpaperState state) {
    final bool locked = switch (_mode) {
      _LiveMode.photo => state.isLocked(state.motionStyle.name, isFree: state.motionStyle.isFree),
      _LiveMode.gradients => state.isLocked(state.gradientStyle.name, isFree: state.gradientStyle.isFree),
      _LiveMode.video => false,
    };
    return locked
        ? context.l10n.wallpaperLiveUnlockCoins(
            NumberFormat.decimalPattern(context.l10n.localeName).format(CoinPolicy.liveWallpaperStyle),
          )
        : context.l10n.wallpaperLiveSetAction;
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.imageUrl, required this.state});

  final String imageUrl;
  final LiveWallpaperState state;

  @override
  Widget build(BuildContext context) {
    final LiveWallpaperBloc bloc = context.read<LiveWallpaperBloc>();
    return Column(
      children: [
        LiveStylePreview(
          semanticLabel: context.l10n.wallpaperLiveApplyPhotoDescription(
            _motionStyleLabel(context.l10n, state.motionStyle),
          ),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 720,
            errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
        const SizedBox(height: 16),
        LiveStylePicker<MotionStyle>(
          values: MotionStyle.values,
          selected: state.motionStyle,
          label: (style) => _motionStyleLabel(context.l10n, style),
          isLocked: (style) => state.isLocked(style.name, isFree: style.isFree),
          onSelected: (style) => bloc.add(LiveWallpaperEvent.motionSelected(style)),
        ),
        const SizedBox(height: 8),
        _Description(text: _motionStyleDescription(context.l10n, state.motionStyle)),
        _BatterySaver(state: state),
      ],
    );
  }
}

class _GradientSection extends StatelessWidget {
  const _GradientSection({
    required this.state,
    required this.palette,
    required this.seeds,
    required this.seedIndex,
    required this.onSeedSelected,
  });

  final LiveWallpaperState state;
  final LivePalette palette;
  final List<Color> seeds;
  final int seedIndex;
  final ValueChanged<int> onSeedSelected;

  @override
  Widget build(BuildContext context) {
    final LiveWallpaperBloc bloc = context.read<LiveWallpaperBloc>();
    return Column(
      children: [
        LiveStylePreview(
          semanticLabel: context.l10n.wallpaperLiveGradientDescription(
            _gradientStyleLabel(context.l10n, state.gradientStyle),
          ),
          child: DecoratedBox(decoration: BoxDecoration(gradient: liveGradientPreview(state.gradientStyle, palette))),
        ),
        const SizedBox(height: 16),
        LiveStylePicker<GradientStyle>(
          values: GradientStyle.values,
          selected: state.gradientStyle,
          label: (style) => _gradientStyleLabel(context.l10n, style),
          isLocked: (style) => state.isLocked(style.name, isFree: style.isFree),
          onSelected: (style) => bloc.add(LiveWallpaperEvent.gradientSelected(style)),
        ),
        const SizedBox(height: 8),
        _Description(text: _gradientStyleDescription(context.l10n, state.gradientStyle)),
        const SizedBox(height: 12),
        _SeedSwatches(seeds: seeds, selected: seedIndex, onSelected: onSeedSelected),
        _BatterySaver(state: state),
      ],
    );
  }
}

class _SeedSwatches extends StatelessWidget {
  const _SeedSwatches({required this.seeds, required this.selected, required this.onSelected});

  final List<Color> seeds;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int index = 0; index < seeds.length; index++)
          Semantics(
            button: true,
            selected: index == selected,
            label: context.l10n.wallpaperLiveGradientSwatch(
              NumberFormat.decimalPattern(context.l10n.localeName).format(index + 1),
              NumberFormat.decimalPattern(context.l10n.localeName).format(seeds.length),
            ),
            child: InkResponse(
              onTap: () => onSelected(index),
              radius: 28,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: seeds[index],
                    shape: BoxShape.circle,
                    border: index == selected ? Border.all(color: scheme.secondary, width: 2) : null,
                  ),
                  child: const SizedBox.square(dimension: 32),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoSection extends StatelessWidget {
  const _VideoSection({required this.state, required this.onChoose});

  final LiveWallpaperState state;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = state.videoPath;
    return Column(
      children: [
        LiveStylePreview(
          semanticLabel: path == null ? context.l10n.wallpaperLiveNoVideo : context.l10n.wallpaperLiveVideoChosen,
          child: ColoredBox(
            color: theme.cardColor,
            child: Center(
              child: Icon(
                path == null ? Icons.video_library_outlined : Icons.movie_rounded,
                size: 48,
                color: theme.colorScheme.secondary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (path != null) ...[
          Text(
            p.basename(path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: state.applying ? null : onChoose,
          icon: const Icon(Icons.video_file_outlined),
          label: Text(
            path == null ? context.l10n.wallpaperLiveChooseVideo : context.l10n.wallpaperLiveChooseAnotherVideo,
          ),
        ),
        const SizedBox(height: 8),
        _Description(text: context.l10n.wallpaperLiveVideoDescription),
      ],
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary.withValues(alpha: 0.7)),
    );
  }
}

class _BatterySaver extends StatelessWidget {
  const _BatterySaver({required this.state});

  final LiveWallpaperState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.l10n.wallpaperLiveBatterySaver, style: TextStyle(color: theme.colorScheme.secondary)),
      subtitle: Text(context.l10n.wallpaperLiveFps(state.batterySaver ? 15 : 30)),
      value: state.batterySaver,
      onChanged: (value) => context.read<LiveWallpaperBloc>().add(LiveWallpaperEvent.batterySaverChanged(value)),
    );
  }
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.label, required this.busy, required this.enabled, required this.onPressed});

  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: enabled && !busy ? onPressed : null,
                child: busy
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                      )
                    : Text(label),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.wallpaperLivePreviewInstruction,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
