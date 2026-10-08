import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/wallpaper_set_feedback.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/features/wallpaper_position/biz/bloc/wallpaper_position_bloc.j.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:Prism/features/wallpaper_position/views/widgets/placement_panel.dart';
import 'package:Prism/features/wallpaper_position/views/widgets/placement_preview.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pan, zoom, fit and dim a wallpaper before it is set. Pops with the [WallpaperSetResult] when the wall was set.
@RoutePage()
class WallpaperPositionScreen extends StatelessWidget {
  const WallpaperPositionScreen({super.key, required this.imageUrl, this.thumbnailUrl, this.entryPoint});

  final String imageUrl;
  final String? thumbnailUrl;

  /// The screen the user came from, for analytics.
  final String? entryPoint;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WallpaperPositionBloc>(
      create: (_) => getIt<WallpaperPositionBloc>()
        ..add(WallpaperPositionEvent.started(imageUrl: imageUrl, thumbnailUrl: thumbnailUrl, entryPoint: entryPoint)),
      child: _WallpaperPositionView(imageUrl: imageUrl, thumbnailUrl: thumbnailUrl, entryPoint: entryPoint),
    );
  }
}

class _WallpaperPositionView extends StatefulWidget {
  const _WallpaperPositionView({required this.imageUrl, required this.thumbnailUrl, required this.entryPoint});

  final String imageUrl;
  final String? thumbnailUrl;
  final String? entryPoint;

  @override
  State<_WallpaperPositionView> createState() => _WallpaperPositionViewState();
}

class _WallpaperPositionViewState extends State<_WallpaperPositionView> {
  final TransformationController _controller = TransformationController();
  late final Future<aw.WallpaperCapabilities> _capabilities = aw.AsyncWallpaper.getCapabilities();
  WallpaperTarget _lastTarget = WallpaperTarget.both;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onResult(BuildContext context, WallpaperPositionState state) {
    final WallpaperSetResult? result = state.result;
    if (result == null) return;
    final WallpaperPositionBloc bloc = context.read<WallpaperPositionBloc>();
    reportWallpaperSetResult(
      context,
      result,
      target: _lastTarget,
      setContext: WallpaperSetContext(
        fit: 'studio_${state.placement.fit.name}',
        entryPoint: widget.entryPoint ?? 'position_studio',
      ),
      onRetry: (target) => _apply(bloc, target),
    );
    if (result.isSuccess || result.isInfo) Navigator.of(context).pop(result);
  }

  void _apply(WallpaperPositionBloc bloc, WallpaperTarget target) {
    _lastTarget = target;
    final Size screen = MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
    bloc.add(WallpaperPositionEvent.applyRequested(target: target, outputSize: screen));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size screen = MediaQuery.sizeOf(context);
    return BlocConsumer<WallpaperPositionBloc, WallpaperPositionState>(
      listenWhen: (previous, current) => previous.resultToken != current.resultToken,
      listener: _onResult,
      builder: (context, state) {
        final WallpaperPositionBloc bloc = context.read<WallpaperPositionBloc>();
        final PlacementSource? source = state.source;
        return Scaffold(
          backgroundColor: theme.primaryColor,
          appBar: AppBar(
            backgroundColor: theme.primaryColor,
            title: Text('Position', style: theme.textTheme.displaySmall),
          ),
          body: switch (state.status) {
            WallpaperPositionStatus.loading => const GlintState(
              kind: GlintStateKind.loading,
              title: 'Loading wallpaper',
            ),
            WallpaperPositionStatus.failed => GlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load this wallpaper",
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => bloc.add(
                WallpaperPositionEvent.started(
                  imageUrl: widget.imageUrl,
                  thumbnailUrl: widget.thumbnailUrl,
                  entryPoint: widget.entryPoint,
                ),
              ),
            ),
            WallpaperPositionStatus.ready || WallpaperPositionStatus.applying => Column(
              children: <Widget>[
                _PreviewModeToggle(
                  mode: state.placement.previewMode,
                  onChanged: (mode) => bloc.add(WallpaperPositionEvent.previewModeChanged(mode)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: screen.width / screen.height,
                        child: PlacementPreview(
                          source: source!,
                          placement: state.placement,
                          syncToken: state.syncToken,
                          controller: _controller,
                          onMoved: (dx, dy, zoom) => bloc.add(WallpaperPositionEvent.moved(dx: dx, dy: dy, zoom: zoom)),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Approximate. Your launcher may differ.', style: PrismTextStyles.caption(context)),
                ),
                FutureBuilder<aw.WallpaperCapabilities>(
                  future: _capabilities,
                  builder: (context, snapshot) {
                    final aw.WallpaperCapabilities? capabilities = snapshot.data;
                    return PlacementPanel(
                      placement: state.placement,
                      busy: state.status == WallpaperPositionStatus.applying,
                      targets: <WallpaperTarget>[
                        for (final WallpaperTarget target in WallpaperTarget.values)
                          if (capabilities == null || isWallpaperTargetSupported(capabilities, target)) target,
                      ],
                      onFit: (fit) => bloc.add(WallpaperPositionEvent.fitChanged(fit)),
                      onDim: (dim) => bloc.add(WallpaperPositionEvent.dimChanged(dim)),
                      onReset: () => bloc.add(const WallpaperPositionEvent.resetRequested()),
                      onSet: (target) => _apply(bloc, target),
                    );
                  },
                ),
              ],
            ),
          },
        );
      },
    );
  }
}

class _PreviewModeToggle extends StatelessWidget {
  const _PreviewModeToggle({required this.mode, required this.onChanged});

  final PlacementPreviewMode mode;
  final ValueChanged<PlacementPreviewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SegmentedButton<PlacementPreviewMode>(
        showSelectedIcon: false,
        segments: const <ButtonSegment<PlacementPreviewMode>>[
          ButtonSegment<PlacementPreviewMode>(value: PlacementPreviewMode.lock, label: Text('Lock')),
          ButtonSegment<PlacementPreviewMode>(value: PlacementPreviewMode.home, label: Text('Home')),
        ],
        selected: <PlacementPreviewMode>{mode},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
