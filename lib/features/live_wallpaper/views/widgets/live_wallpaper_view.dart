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
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

enum _LiveMode {
  photo('Make it live'),
  gradients('Gradients'),
  video('Video');

  const _LiveMode(this.label);

  final String label;
}

enum _UnlockChoice { coins, pro }

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
              content: Text(outcome.message, style: TextStyle(color: outcome.isError ? scheme.onError : null)),
              backgroundColor: outcome.isError ? scheme.error : null,
            ),
          );
    }
  }

  /// The style the user tried to apply: its id, its name and its price are what the unlock sheet shows.
  (String id, String label) get _lockedStyle {
    final LiveWallpaperState state = context.read<LiveWallpaperBloc>().state;
    return _mode == _LiveMode.photo
        ? (state.motionStyle.name, state.motionStyle.label)
        : (state.gradientStyle.name, state.gradientStyle.label);
  }

  Future<void> _offerUnlock(LiveWallpaperBloc bloc) async {
    final (String id, String label) = _lockedStyle;
    final _UnlockChoice? choice = await showPrismSheet<_UnlockChoice>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => PrismSheetBody(
        title: '$label is a paid style',
        message: 'Unlock it for 7 days with coins, or get Prism Pro for every style.',
        actions: <Widget>[
          PrismButton(
            label: 'Unlock $label for 7 days · ${CoinPolicy.liveWallpaperStyle} coins',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(_UnlockChoice.coins),
          ),
          PrismButton(
            label: 'See Prism Pro',
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
          toasts.success('$label is unlocked for 7 days.');
        } else if (result.insufficientBalance) {
          toasts.error('Not enough coins. Earn coins in Rewards.');
        } else {
          toasts.error("Couldn't unlock $label. Try again.");
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
      title: 'Live wallpapers',
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
                title: 'Live wallpapers are not available',
                body: 'They need an Android phone that supports OpenGL live wallpapers.',
                actionLabel: 'Back',
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
                    label: Text(mode.label),
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
                  title: 'Not available on this device',
                  body: videoOff
                      ? 'This device cannot play a video as a wallpaper.'
                      : 'This device cannot run shader live wallpapers. Try Video.',
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
    return locked ? 'Unlock · ${CoinPolicy.liveWallpaperStyle} coins' : 'Set live wallpaper';
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
          semanticLabel: '${state.motionStyle.label} preview',
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
          label: (style) => style.label,
          isLocked: (style) => state.isLocked(style.name, isFree: style.isFree),
          onSelected: (style) => bloc.add(LiveWallpaperEvent.motionSelected(style)),
        ),
        const SizedBox(height: 8),
        _Description(text: state.motionStyle.description),
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
          semanticLabel: '${state.gradientStyle.label} preview',
          child: DecoratedBox(decoration: BoxDecoration(gradient: liveGradientPreview(state.gradientStyle, palette))),
        ),
        const SizedBox(height: 16),
        LiveStylePicker<GradientStyle>(
          values: GradientStyle.values,
          selected: state.gradientStyle,
          label: (style) => style.label,
          isLocked: (style) => state.isLocked(style.name, isFree: style.isFree),
          onSelected: (style) => bloc.add(LiveWallpaperEvent.gradientSelected(style)),
        ),
        const SizedBox(height: 8),
        _Description(text: state.gradientStyle.description),
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
            label: 'Gradient colour ${index + 1} of ${seeds.length}',
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
          semanticLabel: path == null ? 'No video chosen' : 'Chosen video',
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
          label: Text(path == null ? 'Choose a video' : 'Choose another video'),
        ),
        const SizedBox(height: 8),
        const _Description(text: 'Plays on your home screen with the sound off. Up to 256 MB.'),
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
      title: Text('Battery saver', style: TextStyle(color: theme.colorScheme.secondary)),
      subtitle: Text(state.batterySaver ? '15 frames per second' : '30 frames per second'),
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
              'Android opens a preview. Tap Set wallpaper there.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
