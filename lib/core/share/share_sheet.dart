import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/share/instagram_stories.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:Prism/core/share/share_text.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Everything the sheet reaches outside Flutter. Tests swap these out.
class ShareSheetServices {
  const ShareSheetServices({
    this.render = renderShareCardFile,
    this.instagramAvailable = InstagramStories.available,
    this.shareToInstagram = InstagramStories.share,
    this.saveImage = _saveImage,
    this.shareFile = _shareFile,
    this.shareText = _shareText,
    this.copyText = _copyText,
  });

  final ShareCardRender render;
  final Future<bool> Function() instagramAvailable;
  final Future<bool> Function(String imagePath) shareToInstagram;
  final Future<OperationResult> Function(File file) saveImage;
  final Future<ShareResult> Function({required String text, required File file, required BuildContext context})
  shareFile;
  final Future<ShareResult> Function({required String text, required BuildContext context}) shareText;
  final Future<void> Function(String text) copyText;
}

Future<OperationResult> _saveImage(File file) =>
    PrismMediaHostApi().saveMedia(SaveMediaRequest(link: file.path, isLocalFile: true, kind: SaveMediaKind.wallpaper));

Future<ShareResult> _shareFile({required String text, required File file, required BuildContext context}) =>
    ShareService.shareFile(file: file, text: text, context: context);

Future<ShareResult> _shareText({required String text, required BuildContext context}) =>
    ShareService.shareText(text: text, context: context);

Future<void> _copyText(String text) => Clipboard.setData(ClipboardData(text: text));

typedef ShareSheetOpen = Future<void> Function(BuildContext context, ShareCardContent content, String sourceContext);

/// The Prism share sheet: a carousel of card formats on top, one row of targets below.
Future<void> showShareSheet(
  BuildContext context,
  ShareCardContent content,
  String sourceContext, {
  ShareSheetServices services = const ShareSheetServices(),
}) {
  return showPrismSheet<void>(
    context,
    builder: (_) => ShareSheet(
      content: ShareCardContent(
        imageUrl: content.imageUrl,
        link: content.link,
        brandName: content.brandName,
        contextLine: shareSafeText(content.contextLine),
        creator: shareSafeText(content.creator),
        creatorLine: shareSafeText(content.creatorLine),
        palette: content.palette,
      ),
      sourceContext: sourceContext,
      services: services,
    ),
  );
}

class ShareSheet extends StatefulWidget {
  const ShareSheet({
    required this.content,
    required this.sourceContext,
    this.services = const ShareSheetServices(),
    super.key,
  });

  final ShareCardContent content;
  final String sourceContext;
  final ShareSheetServices services;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final PageController _pages = PageController(viewportFraction: 0.62);
  final Map<ShareCardFormat, Future<File>> _renders = <ShareCardFormat, Future<File>>{};
  ShareCardFormat _format = ShareCardFormat.values.first;
  bool _instagram = false;
  ShareTargetValue? _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_checkInstagram());
  }

  Future<void> _checkInstagram() async {
    bool available = false;
    try {
      available = await widget.services.instagramAvailable();
    } catch (error, stackTrace) {
      logger.w('Instagram availability check failed', error: error, stackTrace: stackTrace);
    }
    if (mounted && available) setState(() => _instagram = true);
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final Future<File> render in _renders.values) {
      unawaited(
        render.then((File file) => file.delete()).then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {}),
      );
    }
    super.dispose();
  }

  /// Renders each format at most once while the sheet is open.
  Future<File> _render(ShareCardFormat format) =>
      _renders.putIfAbsent(format, () => widget.services.render(format, widget.content));

  String get _text => context.l10n.coreShareCardClipboard(widget.content.link);

  void _track(ShareTargetValue target, EventResultValue result, {ShareFormatValue? format}) {
    analytics.track(
      InviteShareResultEvent(
        channel: target == ShareTargetValue.copyLink ? ShareChannelValue.link : ShareChannelValue.shareSheet,
        result: result,
        reason: switch (result) {
          EventResultValue.failure => AnalyticsReasonValue.error,
          EventResultValue.cancelled => AnalyticsReasonValue.userCancelled,
          _ => null,
        },
        sourceContext: widget.sourceContext,
        format: format,
        target: target,
      ),
    );
  }

  Future<void> _run(ShareTargetValue target, Future<bool> Function() action) async {
    if (_busy != null) return;
    PrismHaptics.tap();
    setState(() => _busy = target);
    bool done = false;
    try {
      done = await action();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
    if (done && mounted) Navigator.of(context).maybePop();
  }

  Future<bool> _copyLink() async {
    final AppLocalizations l10n = context.l10n;
    await widget.services.copyText(widget.content.link);
    _track(ShareTargetValue.copyLink, EventResultValue.success);
    toasts.success(l10n.coreShareLinkCopied);
    return true;
  }

  Future<bool> _saveImage() async {
    final ShareCardFormat format = _format;
    final AppLocalizations l10n = context.l10n;
    try {
      final OperationResult result = await widget.services.saveImage(await _render(format));
      if (result.success) {
        _track(ShareTargetValue.saveImage, EventResultValue.success, format: format.analytics);
        toasts.success(l10n.coreShareImageSaved);
        return true;
      }
      _track(ShareTargetValue.saveImage, EventResultValue.failure, format: format.analytics);
      if (!mounted) return false;
      if (isPhotosPermissionDenied(result.errorCode)) {
        showPhotosPermissionDenied(context);
      } else {
        toasts.error(l10n.coreShareImageFailed);
      }
    } catch (error, stackTrace) {
      logger.w('Share card save failed', error: error, stackTrace: stackTrace);
      _track(ShareTargetValue.saveImage, EventResultValue.failure, format: format.analytics);
      toasts.error(l10n.coreShareImageFailed);
    }
    return false;
  }

  Future<bool> _shareInstagram() async {
    final ShareCardFormat format = _format;
    final AppLocalizations l10n = context.l10n;
    bool opened = false;
    try {
      opened = await widget.services.shareToInstagram((await _render(format)).path);
    } catch (error, stackTrace) {
      logger.w('Instagram story share failed', error: error, stackTrace: stackTrace);
    }
    _track(
      ShareTargetValue.instagramStories,
      opened ? EventResultValue.success : EventResultValue.failure,
      format: format.analytics,
    );
    if (!opened) toasts.error(l10n.coreShareInstagramFailed);
    return opened;
  }

  /// The system sheet with the selected card, or with the text link when the card cannot be made.
  Future<bool> _more() async {
    final ShareCardFormat format = _format;
    final String text = _text;
    File? file;
    try {
      file = await _render(format);
    } catch (error, stackTrace) {
      logger.w('Share card failed; sharing text', error: error, stackTrace: stackTrace);
    }
    if (!mounted) return false;
    try {
      final ShareResult sent = file == null
          ? await widget.services.shareText(text: text, context: context)
          : await widget.services.shareFile(text: text, file: file, context: context);
      final bool dismissed = sent.status == ShareResultStatus.dismissed;
      _track(
        ShareTargetValue.more,
        dismissed ? EventResultValue.cancelled : EventResultValue.success,
        format: file == null ? ShareFormatValue.text : format.analytics,
      );
      return !dismissed;
    } catch (error, stackTrace) {
      logger.w('System share failed', error: error, stackTrace: stackTrace);
      _track(ShareTargetValue.more, EventResultValue.failure, format: file == null ? ShareFormatValue.text : null);
      if (mounted) toasts.error(context.l10n.coreWallpaperShareRetryFailed);
      return false;
    }
  }

  String _formatLabel(AppLocalizations l10n, ShareCardFormat format) => switch (format) {
    ShareCardFormat.story => l10n.coreShareFormatStory,
    ShareCardFormat.post => l10n.coreShareFormatPost,
    ShareCardFormat.clean => l10n.coreShareFormatClean,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final double height = (MediaQuery.sizeOf(context).height * 0.46).clamp(240.0, 440.0);
    return PrismSheetBody(
      title: l10n.coreShare,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: height,
            child: PageView.builder(
              key: const ValueKey<String>('share-formats'),
              controller: _pages,
              itemCount: ShareCardFormat.values.length,
              onPageChanged: (int index) {
                PrismHaptics.selection();
                setState(() => _format = ShareCardFormat.values[index]);
              },
              itemBuilder: (BuildContext context, int index) {
                final ShareCardFormat format = ShareCardFormat.values[index];
                final bool selected = format == _format;
                return _FormatPreview(
                  key: ValueKey<ShareCardFormat>(format),
                  format: format,
                  label: _formatLabel(l10n, format),
                  selected: selected,
                  render: selected || _renders.containsKey(format) ? _render(format) : null,
                  onTap: selected
                      ? null
                      : () => _pages.animateToPage(
                          index,
                          duration: context.motion(PrismDurations.base),
                          curve: PrismCurves.move,
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: PrismSpace.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_instagram)
                  _ShareTarget(
                    key: const ValueKey<ShareTargetValue>(ShareTargetValue.instagramStories),
                    icon: JamIcons.instagram,
                    label: l10n.coreShareTargetInstagram,
                    busy: _busy == ShareTargetValue.instagramStories,
                    onTap: () => _run(ShareTargetValue.instagramStories, _shareInstagram),
                  ),
                _ShareTarget(
                  key: const ValueKey<ShareTargetValue>(ShareTargetValue.copyLink),
                  icon: Icons.link_rounded,
                  label: l10n.coreShareTargetCopyLink,
                  busy: _busy == ShareTargetValue.copyLink,
                  onTap: () => _run(ShareTargetValue.copyLink, _copyLink),
                ),
                _ShareTarget(
                  key: const ValueKey<ShareTargetValue>(ShareTargetValue.saveImage),
                  icon: Icons.download_rounded,
                  label: l10n.coreShareTargetSaveImage,
                  busy: _busy == ShareTargetValue.saveImage,
                  onTap: () => _run(ShareTargetValue.saveImage, _saveImage),
                ),
                _ShareTarget(
                  key: const ValueKey<ShareTargetValue>(ShareTargetValue.more),
                  icon: Icons.more_horiz_rounded,
                  label: l10n.coreShareTargetMore,
                  busy: _busy == ShareTargetValue.more,
                  onTap: () => _run(ShareTargetValue.more, _more),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrismSpace.md),
        ],
      ),
    );
  }
}

class _FormatPreview extends StatelessWidget {
  const _FormatPreview({
    required this.format,
    required this.label,
    required this.selected,
    required this.render,
    required this.onTap,
    super.key,
  });

  final ShareCardFormat format;
  final String label;
  final bool selected;
  final Future<File>? render;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Duration duration = context.motion(PrismDurations.fast);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1 : 0.9,
          duration: duration,
          curve: PrismCurves.move,
          child: AnimatedOpacity(
            opacity: selected ? 1 : 0.6,
            duration: duration,
            curve: PrismCurves.move,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: format.size.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                        child: ColoredBox(
                          color: cs.surfaceContainerHigh,
                          child: FutureBuilder<File>(
                            future: render,
                            builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
                              if (snapshot.hasData) {
                                return Image.file(
                                  snapshot.requireData,
                                  key: ValueKey<String>('share-preview-${format.name}'),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  excludeFromSemantics: true,
                                );
                              }
                              if (snapshot.hasError) return _PreviewFallback(format: format);
                              return const PrismSkeleton(
                                child: PrismBone(width: double.infinity, height: double.infinity, radius: 0),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PrismSpace.xs),
                Text(
                  label,
                  style: PrismTextStyles.rowTitle(
                    context,
                  ).copyWith(color: selected ? cs.onSurface : cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback({required this.format});

  final ShareCardFormat format;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey<String>('share-preview-fallback-${format.name}'),
      padding: const EdgeInsets.all(PrismSpace.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.link_rounded, color: cs.onSurfaceVariant),
          const SizedBox(height: PrismSpace.xs),
          Text(
            context.l10n.coreSharePreviewFailed,
            textAlign: TextAlign.center,
            style: PrismTextStyles.caption(context),
          ),
        ],
      ),
    );
  }
}

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({required this.icon, required this.label, required this.busy, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(
              children: <Widget>[
                SizedBox.square(
                  dimension: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.08), shape: BoxShape.circle),
                    child: Center(
                      child: busy
                          ? SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                            )
                          : Icon(icon, color: cs.onSurface),
                    ),
                  ),
                ),
                const SizedBox(height: PrismSpace.xs),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.caption(context).copyWith(color: cs.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
