import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/firestore/firestore_server_read.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

final RegExp _wallIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,200}$');
final RegExp _shortLinkPath = RegExp(r'^/l/[A-Za-z0-9]{7,10}$');

/// The link a computer opens: the short link with the desktop hint, or the wall page in desktop mode.
Uri? openOnComputerLink({required String wallId, required String shareLink}) {
  if (!_wallIdPattern.hasMatch(wallId)) return null;
  final Uri? parsed = Uri.tryParse(shareLink);
  if (parsed != null &&
      parsed.scheme == 'https' &&
      parsed.host == 'prismwalls.com' &&
      _shortLinkPath.hasMatch(parsed.path)) {
    return Uri.https('prismwalls.com', parsed.path, <String, String>{'d': '1'});
  }
  return Uri.https('prismwalls.com', '/wallpaper/$wallId', <String, String>{'view': 'desktop'});
}

/// The link as people type it: no scheme.
String openOnComputerDisplay(Uri link) => openOnComputerDisplayParts(link).join();

/// The link split where a line may break, so no line ever cuts the host or the short code.
List<String> openOnComputerDisplayParts(Uri link) => <String>[
  link.host,
  link.path,
  if (link.hasQuery) '?${link.query}',
];

/// True when the public web catalogue shows this wall with its image
/// (`webWalls/<id>.state` is `live` and it has a thumb).
Future<bool> isOnWebCatalogue(String wallId) async {
  try {
    final Map<String, dynamic>? data = await firestoreClient.getFromServer<Map<String, dynamic>>(
      FirebaseCollections.webWalls,
      wallId,
      (Map<String, dynamic> data, String _) => data,
      sourceTag: 'share.open_on_computer.web_wall',
    );
    final Object? thumb = data?['thumb'];
    return data != null && data['state'] == 'live' && thumb is String && thumb.isNotEmpty;
  } on Object {
    return false;
  }
}

Future<void> _copyToClipboard(String text) => Clipboard.setData(ClipboardData(text: text));

Future<void> showOpenOnComputerSheet(
  BuildContext context, {
  required Uri link,
  required String sourceContext,
  Future<void> Function(String text)? copyText,
}) {
  return showPrismSheet<void>(
    context,
    builder: (_) =>
        OpenOnComputerSheet(link: link, sourceContext: sourceContext, copyText: copyText ?? _copyToClipboard),
  );
}

class OpenOnComputerSheet extends StatefulWidget {
  const OpenOnComputerSheet({required this.link, required this.sourceContext, required this.copyText, super.key});

  final Uri link;
  final String sourceContext;
  final Future<void> Function(String text) copyText;

  @override
  State<OpenOnComputerSheet> createState() => _OpenOnComputerSheetState();
}

class _OpenOnComputerSheetState extends State<OpenOnComputerSheet> {
  @override
  void initState() {
    super.initState();
    analytics.track(OpenOnComputerShownEvent(sourceContext: widget.sourceContext));
  }

  Future<void> _copy() async {
    final AppLocalizations l10n = context.l10n;
    try {
      await widget.copyText(widget.link.toString());
      analytics.track(
        OpenOnComputerLinkCopiedEvent(sourceContext: widget.sourceContext, result: EventResultValue.success),
      );
      if (mounted) toasts.success(l10n.coreShareLinkCopied);
    } catch (e, s) {
      logger.w('Open on computer copy failed', error: e, stackTrace: s);
      analytics.track(
        OpenOnComputerLinkCopiedEvent(sourceContext: widget.sourceContext, result: EventResultValue.failure),
      );
      if (mounted) toasts.error(l10n.coreWallpaperLinkCopyFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l10n = context.l10n;
    final String display = openOnComputerDisplay(widget.link);
    return PrismSheetBody(
      title: l10n.coreShareOpenOnComputer,
      centered: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.coreShareOpenOnComputerBody,
            textAlign: TextAlign.center,
            style: PrismTextStyles.body(context).copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: PrismSpace.lg),
          Semantics(
            image: true,
            label: l10n.coreShareOpenOnComputerQr(display),
            excludeSemantics: true,
            child: QrTile(key: const ValueKey<String>('open-on-computer-qr'), data: widget.link.toString()),
          ),
          const SizedBox(height: PrismSpace.lg),
          Semantics(
            label: display,
            excludeSemantics: true,
            child: Wrap(
              key: const ValueKey<String>('open-on-computer-link'),
              alignment: WrapAlignment.center,
              children: <Widget>[
                for (final String part in openOnComputerDisplayParts(widget.link))
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      part,
                      softWrap: false,
                      style: PrismTextStyles.sheetHeadline(context).copyWith(
                        fontSize: 24,
                        height: 1.3,
                        letterSpacing: 0.4,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: PrismSpace.xl),
          PrismButton(
            key: const ValueKey<String>('open-on-computer-copy'),
            label: l10n.coreShareTargetCopyLink,
            icon: Icons.link_rounded,
            expand: true,
            onPressed: _copy,
          ),
        ],
      ),
    );
  }
}

// Fixed on every theme: scanners need dark modules on a light field.
const Color _qrLight = Color(0xFFFFFFFF);
const Color _qrDark = Color(0xFF000000);

class QrTile extends StatelessWidget {
  const QrTile({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final QrImage image = QrImage(QrCode(payload: QrPayload.fromString(data)));
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double side = math.min(constraints.maxWidth, 260);
        return Container(
          width: side,
          height: side,
          decoration: BoxDecoration(color: _qrLight, borderRadius: BorderRadius.circular(PrismRadius.md)),
          child: CustomPaint(painter: _QrPainter(image), size: Size.square(side)),
        );
      },
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    const int quietZone = 4;
    final int cells = image.moduleCount + quietZone * 2;
    final double cell = size.width / cells;
    final Paint paint = Paint()
      ..color = _qrDark
      ..isAntiAlias = false;
    for (int row = 0; row < image.moduleCount; row++) {
      for (int col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(Rect.fromLTWH((col + quietZone) * cell, (row + quietZone) * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
