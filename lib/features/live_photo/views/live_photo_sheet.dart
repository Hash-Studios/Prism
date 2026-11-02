import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/live_photo/biz/bloc/live_photo_bloc.j.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/domain/repositories/live_photo_repository.dart';
import 'package:Prism/features/live_photo/views/widgets/live_photo_preview.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_style_unlock.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the Live Photo sheet for one wall, then the guide after a save. iOS only.
///
/// [resolveSource] runs on each Save and returns the wall the user may export, after sign-in and any consent.
/// [preview] is the image the sheet animates. [depthMapUrl] turns on the 3D style.
Future<void> showLivePhotoSheet(
  BuildContext context, {
  required String wallId,
  required Future<String?> Function() resolveSource,
  ImageProvider? preview,
  String? depthMapUrl,
  Color? tint,
  LivePhotoRepository? repository,
  bool Function()? canExport,
}) async {
  final String owner = app_state.prismUser.id;
  bool allowed(MotionStyle style) =>
      app_state.prismUser.loggedIn &&
      app_state.prismUser.id == owner &&
      (canExport?.call() ?? true) &&
      !isLiveStyleLocked(
        style.name,
        isFree: style.isFree,
        isPro: app_state.prismUser.premium,
        unlockedStyles: liveStyleUnlocks(),
      );
  final bool? saved = await showPrismSheet<bool>(
    context,
    builder: (_) => BlocProvider<LivePhotoBloc>(
      create: (_) => LivePhotoBloc(
        repository ?? getIt<LivePhotoRepository>(),
        wallId: wallId,
        resolveSource: resolveSource,
        depthMapUrl: depthMapUrl,
        isPro: app_state.prismUser.premium,
        unlockedStyles: liveStyleUnlocks(),
        canExport: allowed,
      ),
      child: _LivePhotoAccessWatch(
        canExport: allowed,
        child: LivePhotoSheet(preview: preview, tint: tint),
      ),
    ),
  );
  if (saved == true && context.mounted) await showLivePhotoGuide(context);
}

class _LivePhotoAccessWatch extends StatefulWidget {
  const _LivePhotoAccessWatch({required this.canExport, required this.child});

  final bool Function(MotionStyle) canExport;
  final Widget child;

  @override
  State<_LivePhotoAccessWatch> createState() => _LivePhotoAccessWatchState();
}

class _LivePhotoAccessWatchState extends State<_LivePhotoAccessWatch> with WidgetsBindingObserver {
  StreamSubscription<Object?>? _session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CoinsService.instance.passesNotifier.addListener(_refresh);
    if (getIt.isRegistered<SessionRepository>()) {
      _session = getIt<SessionRepository>().watchCurrentUser().listen((_) => _refresh());
    }
  }

  void _refresh() {
    if (!mounted) return;
    final LivePhotoBloc bloc = context.read<LivePhotoBloc>();
    if (bloc.isClosed) return;
    bloc.add(LivePhotoEvent.accessChanged(isPro: app_state.prismUser.premium, unlockedStyles: liveStyleUnlocks()));
    if (bloc.state.phase == LivePhotoPhase.exporting && !widget.canExport(bloc.state.style)) {
      bloc.add(const LivePhotoEvent.cancelRequested());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CoinsService.instance.passesNotifier.removeListener(_refresh);
    unawaited(_session?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showLivePhotoGuide(BuildContext context) async {
  unawaited(analytics.track(const LivePhotoGuideOpenedEvent()));
  await showPrismSheet<void>(context, builder: (_) => const LivePhotoGuideSheet());
}

Future<void> _launch(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (error, stackTrace) {
    logger.w('Could not open $url', error: error, stackTrace: stackTrace);
  }
}

class LivePhotoSheet extends StatelessWidget {
  const LivePhotoSheet({super.key, this.preview, this.tint});

  final ImageProvider? preview;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LivePhotoBloc, LivePhotoState>(
      listenWhen: (previous, current) => previous.phase != current.phase,
      listener: (context, state) {
        switch (state.phase) {
          case LivePhotoPhase.saved:
            PrismHaptics.success();
            Navigator.of(context).pop(true);
          case LivePhotoPhase.refused || LivePhotoPhase.failed:
            PrismHaptics.error();
          case LivePhotoPhase.picking || LivePhotoPhase.exporting:
            break;
        }
      },
      builder: (context, state) {
        final AppLocalizations l10n = context.l10n;
        final Color glow = tint ?? Theme.of(context).colorScheme.primary;
        return switch (state.phase) {
          LivePhotoPhase.refused => _RefusedBody(
            restricted: (state.outcome as LiveExportRefused?)?.restricted ?? false,
          ),
          LivePhotoPhase.failed => _FailedBody(outcome: state.outcome),
          LivePhotoPhase.picking || LivePhotoPhase.exporting || LivePhotoPhase.saved => PrismSheetBody(
            title: l10n.livePhotoTitle,
            message: l10n.livePhotoBody,
            actions: <Widget>[
              if (state.phase == LivePhotoPhase.picking)
                PrismButton(
                  key: const ValueKey<String>('live-photo-save'),
                  label: l10n.livePhotoSave,
                  icon: Icons.motion_photos_on_rounded,
                  expand: true,
                  onPressed: () => _save(context, state, glow),
                )
              else
                PrismButton(
                  key: const ValueKey<String>('live-photo-cancel'),
                  label: l10n.coreCancel,
                  variant: PrismButtonVariant.tonal,
                  expand: true,
                  onPressed: state.cancelling || state.phase != LivePhotoPhase.exporting
                      ? null
                      : () => context.read<LivePhotoBloc>().add(const LivePhotoEvent.cancelRequested()),
                ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Semantics(
                    image: true,
                    label: l10n.livePhotoPreview(liveMotionStyleLabel(l10n, state.style)),
                    child: LivePhotoPreview(image: preview, style: state.style, tint: glow),
                  ),
                ),
                const SizedBox(height: PrismSpace.md),
                AnimatedSwitcher(
                  duration: context.motion(PrismDurations.fast),
                  switchInCurve: PrismCurves.enter,
                  switchOutCurve: PrismCurves.exit,
                  child: state.phase == LivePhotoPhase.picking
                      ? _StylePicker(key: const ValueKey<String>('picker'), state: state)
                      : _Progress(key: const ValueKey<String>('progress'), state: state),
                ),
              ],
            ),
          ),
        };
      },
    );
  }

  Future<void> _save(BuildContext context, LivePhotoState state, Color glow) async {
    final LivePhotoBloc bloc = context.read<LivePhotoBloc>();
    if (state.isLocked(state.style)) {
      await offerLiveStyleUnlock(
        context,
        styleId: state.style.name,
        label: liveMotionStyleLabel(context.l10n, state.style),
        source: 'live_photo_sheet',
      );
      if (!context.mounted || bloc.isClosed) return;
      bloc.add(LivePhotoEvent.accessChanged(isPro: app_state.prismUser.premium, unlockedStyles: liveStyleUnlocks()));
      return;
    }
    PrismHaptics.tap();
    final MediaQueryData media = MediaQuery.of(context);
    final Size points = media.size;
    final Size pixels = Size(points.shortestSide * media.devicePixelRatio, points.longestSide * media.devicePixelRatio);
    bloc.add(LivePhotoEvent.exportRequested(sizePx: pixels, tint: glow));
  }
}

class _StylePicker extends StatelessWidget {
  const _StylePicker({super.key, required this.state});

  final LivePhotoState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.livePhotoStyleGroup,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: PrismSpace.xs,
        runSpacing: PrismSpace.xs,
        children: <Widget>[
          for (final MotionStyle style in state.styles)
            Semantics(
              selected: style == state.style,
              label: state.isLocked(style) ? l10n.livePhotoStyleLocked(liveMotionStyleLabel(l10n, style)) : null,
              child: PrismChip(
                key: ValueKey<String>('live-photo-style-${style.name}'),
                label: liveMotionStyleLabel(l10n, style),
                icon: state.isLocked(style) ? Icons.lock_rounded : null,
                selected: style == state.style,
                onTap: () {
                  PrismHaptics.selection();
                  context.read<LivePhotoBloc>().add(LivePhotoEvent.styleSelected(style));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({super.key, required this.state});

  final LivePhotoState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String percent = NumberFormat.percentPattern(l10n.localeName).format(state.progress);
    final String status = state.cancelling
        ? l10n.livePhotoCancelling
        : state.progress >= 1
        ? l10n.livePhotoSaving
        : l10n.livePhotoRendering;
    return Semantics(
      liveRegion: true,
      label: status,
      value: percent,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(status, textAlign: TextAlign.center, style: PrismTextStyles.rowTitle(context)),
            const SizedBox(height: PrismSpace.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(PrismRadius.pill),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: state.progress >= 1 || state.cancelling ? null : state.progress,
                color: scheme.primary,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: PrismSpace.xxs),
            Text(
              l10n.livePhotoProgress(percent),
              textAlign: TextAlign.center,
              style: PrismTextStyles.caption(
                context,
              ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefusedBody extends StatelessWidget {
  const _RefusedBody({required this.restricted});

  final bool restricted;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismSheetBody(
      title: l10n.livePhotoRefusedTitle,
      message: restricted ? l10n.livePhotoRestrictedBody : l10n.livePhotoRefusedBody,
      actions: <Widget>[
        PrismButton(
          key: const ValueKey<String>('live-photo-open-settings'),
          label: l10n.coreOpenSettings,
          icon: Icons.settings_rounded,
          expand: true,
          onPressed: () => _launch('app-settings:'),
        ),
        PrismButton(
          label: l10n.livePhotoNotNow,
          variant: PrismButtonVariant.ghost,
          expand: true,
          onPressed: () => context.read<LivePhotoBloc>().add(const LivePhotoEvent.reset()),
        ),
      ],
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.outcome});

  final LiveExportOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String message = switch (outcome) {
      LiveExportTimedOut() => l10n.livePhotoFailedTimeout,
      LiveExportFailed(reason: LiveExportFailure.sourceUnavailable) => l10n.livePhotoFailedSource,
      LiveExportFailed(reason: LiveExportFailure.saveFailed || LiveExportFailure.notLive) => l10n.livePhotoFailedSave,
      _ => l10n.livePhotoFailedGeneric,
    };
    return PrismSheetBody(
      title: l10n.livePhotoFailedTitle,
      message: message,
      actions: <Widget>[
        PrismButton(
          key: const ValueKey<String>('live-photo-try-again'),
          label: l10n.livePhotoTryAgain,
          expand: true,
          onPressed: () => context.read<LivePhotoBloc>().add(const LivePhotoEvent.reset()),
        ),
      ],
    );
  }
}

/// How to set the saved Live Photo as the Lock Screen wallpaper, with honest notes on where motion plays.
class LivePhotoGuideSheet extends StatelessWidget {
  const LivePhotoGuideSheet({super.key});

  static List<String> steps(AppLocalizations l10n) => <String>[
    l10n.livePhotoGuideStep1,
    l10n.livePhotoGuideStep2,
    l10n.livePhotoGuideStep3,
  ];

  static List<String> notes(AppLocalizations l10n) => <String>[
    l10n.livePhotoGuideNoteWake,
    l10n.livePhotoGuideNoteLowPower,
    l10n.livePhotoGuideNoteNotAvailable,
    l10n.livePhotoGuideNoteVersion,
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return PrismSheetBody(
      title: l10n.livePhotoGuideTitle,
      message: l10n.livePhotoGuideBody,
      actions: <Widget>[
        PrismButton(
          key: const ValueKey<String>('live-photo-open-photos'),
          label: l10n.coreOpenPhotos,
          icon: Icons.photo_library_rounded,
          expand: true,
          onPressed: () {
            PrismHaptics.tap();
            _launch('photos-redirect://');
          },
        ),
        PrismButton(
          label: l10n.coreDone,
          variant: PrismButtonVariant.ghost,
          expand: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GuideNumberedSteps(steps: steps(l10n)),
          const SizedBox(height: PrismSpace.md),
          Semantics(
            header: true,
            child: Text(l10n.livePhotoGuideNotesTitle, style: PrismTextStyles.cardTitle(context)),
          ),
          const SizedBox(height: PrismSpace.xs),
          for (final String note in notes(l10n))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2, end: PrismSpace.sm),
                    child: Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Expanded(child: Text(note, style: PrismTextStyles.body(context))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
