import 'dart:io';

import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

// ignore: avoid_classes_with_only_static_members
class ShareService {
  static Future<ShareResult> shareText({
    required String text,
    String? subject,
    String? title,
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    if (!await _allowed(context) || (context != null && !context.mounted)) {
      return const ShareResult('', ShareResultStatus.dismissed);
    }
    return SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        title: title,
        sharePositionOrigin: sharePositionOrigin ?? _resolveSharePositionOrigin(context),
      ),
    );
  }

  static Future<ShareResult> shareFile({
    required File file,
    required String text,
    String? title,
    BuildContext? context,
  }) async {
    if (!await _allowed(context) || (context != null && !context.mounted)) {
      return const ShareResult('', ShareResultStatus.dismissed);
    }
    return SharePlus.instance.share(
      ShareParams(
        text: text,
        title: title,
        files: <XFile>[XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: _resolveSharePositionOrigin(context),
      ),
    );
  }

  static Future<bool> _allowed(BuildContext? context) async {
    if (context == null) return app_state.prismUser.loggedIn;
    return await requireSignedInAction(context) && context.mounted;
  }

  static Rect _resolveSharePositionOrigin(BuildContext? context) {
    if (context == null) {
      return const Rect.fromLTWH(1, 1, 1, 1);
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.size.width > 0 &&
        renderObject.size.height > 0) {
      final Offset origin = renderObject.localToGlobal(Offset.zero);
      return origin & renderObject.size;
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }
}
