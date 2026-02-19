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

  static Future<ShareResult> shareFiles({
    required List<XFile> files,
    String? text,
    String? subject,
    String? title,
    BuildContext? context,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) {
    if (files.isEmpty) {
      throw ArgumentError.value(files, 'files', 'At least one file is required.');
    }
    return SharePlus.instance.share(
      ShareParams(
        files: files,
        text: text,
        subject: subject,
        title: title,
        fileNameOverrides: fileNameOverrides,
        sharePositionOrigin: sharePositionOrigin ?? _resolveSharePositionOrigin(context),
      ),
    );
  }

  static Future<ShareResult> shareFilePaths({
    required List<String> filePaths,
    String? text,
    String? subject,
    String? title,
    BuildContext? context,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) {
    if (filePaths.isEmpty) {
      throw ArgumentError.value(filePaths, 'filePaths', 'At least one file path is required.');
    }
    final List<XFile> files = filePaths.map((path) => XFile(path)).toList(growable: false);
    return shareFiles(
      files: files,
      text: text,
      subject: subject,
      title: title,
      context: context,
      sharePositionOrigin: sharePositionOrigin,
      fileNameOverrides: fileNameOverrides,
    );
  }

  static Rect _resolveSharePositionOrigin(BuildContext? context) {
    if (context == null) {
      return const Rect.fromLTWH(1, 1, 1, 1);
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final Offset origin = renderObject.localToGlobal(Offset.zero);
      return origin & renderObject.size;
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }
}
