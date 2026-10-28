import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/features/wallpaper_position/biz/bloc/wallpaper_position_bloc.j.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:Prism/features/wallpaper_position/views/widgets/placement_panel.dart';
import 'package:Prism/features/wallpaper_position/views/widgets/placement_preview.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pan, zoom, fit and dim a wallpaper before it is set.
/// Pops with a [StudioResult]: the wall rendered as placed, or a request for the system editor.
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

  /// The last tokens the listener acted on. A render error keeps the earlier [PlacedWallpaper],
  /// so the token tells the two cases apart.
  int _handledPlacedToken = 0;
  int _handledRenderErrorToken = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size screen = MediaQuery.sizeOf(context);
    final double statusBarInset = MediaQuery.viewPaddingOf(context).top;
    return BlocConsumer<WallpaperPositionBloc, WallpaperPositionState>(
      listenWhen: (previous, current) =>
          previous.placedToken != current.placedToken || previous.renderErrorToken != current.renderErrorToken,
      listener: (context, state) {
        if (state.placedToken != _handledPlacedToken) {
          _handledPlacedToken = state.placedToken;
          final PlacedWallpaper? placed = state.placed;
          if (placed != null) Navigator.of(context).pop<StudioResult>(placed);
        }
        if (state.renderErrorToken != _handledRenderErrorToken) {
          _handledRenderErrorToken = state.renderErrorToken;
          toasts.error(context.l10n.wallpaperGenericError);
        }
      },
      builder: (context, state) {
        final WallpaperPositionBloc bloc = context.read<WallpaperPositionBloc>();
        final PlacementSource? source = state.source;
        return Scaffold(
          backgroundColor: theme.primaryColor,
          appBar: AppBar(
            backgroundColor: theme.primaryColor,
            title: Text(context.l10n.setScreenAdjust, style: theme.textTheme.displaySmall),
          ),
          body: switch (state.status) {
            WallpaperPositionStatus.loading => GlintState(
              kind: GlintStateKind.loading,
              title: context.l10n.wallpaperLoadingWallpaper,
            ),
            WallpaperPositionStatus.failed => GlintState(
              kind: GlintStateKind.error,
              title: context.l10n.wallpaperOpenError,
              body: context.l10n.wallpaperCheckConnection,
              actionLabel: context.l10n.wallpaperTryAgain,
              onAction: () => bloc.add(
                WallpaperPositionEvent.started(
                  imageUrl: widget.imageUrl,
                  thumbnailUrl: widget.thumbnailUrl,
                  entryPoint: widget.entryPoint,
                ),
              ),
            ),
            WallpaperPositionStatus.ready || WallpaperPositionStatus.rendering => Column(
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
                          statusBarInset: statusBarInset,
                          onMoved: (dx, dy, zoom) => bloc.add(WallpaperPositionEvent.moved(dx: dx, dy: dy, zoom: zoom)),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(context.l10n.wallpaperPositionApproximate, style: PrismTextStyles.caption(context)),
                ),
                PlacementPanel(
                  placement: state.placement,
                  busy: state.status == WallpaperPositionStatus.rendering,
                  onFit: (fit) => bloc.add(WallpaperPositionEvent.fitChanged(fit)),
                  onDim: (dim) => bloc.add(WallpaperPositionEvent.dimChanged(dim)),
                  onReset: () => bloc.add(const WallpaperPositionEvent.resetRequested()),
                  onDone: () => bloc.add(
                    WallpaperPositionEvent.doneRequested(
                      outputSize: MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context),
                    ),
                  ),
                  onSystemEditor: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                      ? () => Navigator.of(context).pop<StudioResult>(const SystemEditorRequested())
                      : null,
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
        segments: <ButtonSegment<PlacementPreviewMode>>[
          ButtonSegment<PlacementPreviewMode>(
            value: PlacementPreviewMode.lock,
            label: Text(context.l10n.wallpaperPreviewLock),
          ),
          ButtonSegment<PlacementPreviewMode>(
            value: PlacementPreviewMode.home,
            label: Text(context.l10n.wallpaperPreviewHome),
          ),
        ],
        selected: <PlacementPreviewMode>{mode},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
