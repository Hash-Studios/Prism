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
  }) {
    return SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        title: title,
        sharePositionOrigin: sharePositionOrigin ?? _resolveSharePositionOrigin(context),
      ),
    );
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
