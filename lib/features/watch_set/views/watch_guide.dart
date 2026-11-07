import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// How to put the watch image on a photo watch face, with honest notes on what Prism cannot do. The steps follow the
/// watch's platform, not the phone's.
class WatchGuide extends StatelessWidget {
  const WatchGuide({super.key, required this.format, this.onShare});

  final WatchFormat format;

  /// Shares the saved watch image. Null hides the button.
  final VoidCallback? onShare;

  static List<String> appleSteps(AppLocalizations l10n) => <String>[
    l10n.watchGuideIosStep1,
    l10n.watchGuideIosStep2,
    l10n.watchGuideIosStep3,
  ];

  static List<String> pixelSteps(AppLocalizations l10n) => <String>[
    l10n.watchGuidePixelStep1,
    l10n.watchGuidePixelStep2,
    l10n.watchGuidePixelStep3,
  ];

  static List<String> galaxySteps(AppLocalizations l10n) => <String>[
    l10n.watchGuideGalaxyStep1,
    l10n.watchGuideGalaxyStep2,
    l10n.watchGuideGalaxyStep3,
  ];

  static List<String> notes(AppLocalizations l10n, WatchPlatform platform) => <String>[
    l10n.watchGuideNoteNoTransfer,
    if (platform == WatchPlatform.appleWatch) ...<String>[l10n.watchGuideNoteShareSheet, l10n.watchGuideNoteAlbum],
    l10n.watchGuideNoteLayout,
    if (platform == WatchPlatform.wearOs) l10n.watchGuideNoteGooglePhotos,
  ];

  Future<void> _openPhotos() async {
    try {
      await launchUrl(Uri.parse('photos-redirect://'), mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      logger.w('Could not open Photos', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool apple = format.platform == WatchPlatform.appleWatch;
    final VoidCallback? share = onShare;
    return PrismSheetBody(
      title: l10n.watchGuideTitle,
      message: apple ? l10n.watchGuideBodyIos : l10n.watchGuideBodyAndroid,
      actions: <Widget>[
        if (share != null)
          PrismButton(
            key: const ValueKey<String>('watch-guide-share'),
            label: l10n.watchGuideShare,
            icon: Icons.ios_share_rounded,
            expand: true,
            maxLines: 3,
            onPressed: share,
          ),
        if (apple)
          PrismButton(
            label: l10n.coreOpenPhotos,
            icon: Icons.photo_library_rounded,
            variant: share == null ? PrismButtonVariant.primary : PrismButtonVariant.tonal,
            expand: true,
            maxLines: 3,
            onPressed: _openPhotos,
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
          if (apple) ...<Widget>[
            GuideNumberedSteps(steps: appleSteps(l10n)),
            const SizedBox(height: PrismSpace.xs),
            Text(l10n.watchGuideIosAlternative, style: PrismTextStyles.body(context)),
          ] else ...<Widget>[
            _Heading(l10n.watchGuidePixelTitle),
            GuideNumberedSteps(steps: pixelSteps(l10n)),
            const SizedBox(height: PrismSpace.sm),
            _Heading(l10n.watchGuideGalaxyTitle),
            GuideNumberedSteps(steps: galaxySteps(l10n)),
          ],
          const SizedBox(height: PrismSpace.md),
          _Heading(l10n.watchGuideNotesTitle),
          for (final String note in notes(l10n, format.platform)) _Note(note),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: PrismSpace.xxs),
    child: Semantics(header: true, child: Text(text, style: PrismTextStyles.cardTitle(context))),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2, end: PrismSpace.sm),
          child: Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Expanded(child: Text(text, style: PrismTextStyles.body(context))),
      ],
    ),
  );
}
