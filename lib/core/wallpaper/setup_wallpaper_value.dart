import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
final class SetupWallpaperValue {
  const SetupWallpaperValue._({
    required this.raw,
    required this.isEncoded,
    required this.primaryUrl,
    required this.deepLinkUrl,
    required this.title,
    required this.subtitle,
  });

  final String raw;
  final bool isEncoded;
  final String primaryUrl;
  final String? deepLinkUrl;
  final String? title;
  final String? subtitle;

  bool get hasDeepLink => (deepLinkUrl ?? '').isNotEmpty;

  static SetupWallpaperValue parse(String? rawValue) {
    final String raw = rawValue?.trim() ?? '';
    if (raw.isEmpty) {
      return const SetupWallpaperValue._(
        raw: '',
        isEncoded: false,
        primaryUrl: '',
        deepLinkUrl: null,
        title: null,
        subtitle: null,
      );
    }
    if (raw.startsWith('[') && raw.endsWith(']')) {
      try {
        final List<String> values = (jsonDecode(raw) as List)
            .map((entry) => entry?.toString() ?? '')
            .toList(growable: false);
        return SetupWallpaperValue._(
          raw: raw,
          isEncoded: true,
          primaryUrl: values.length > 1 ? values[1] : (values.isNotEmpty ? values.first : raw),
          deepLinkUrl: values.length > 1 ? values[1] : null,
          title: values.isNotEmpty ? values[0] : null,
          subtitle: values.length > 2 ? values[2] : null,
        );
      } catch (_) {
        // Fallback to direct url when legacy payload is malformed.
      }
    }
    return SetupWallpaperValue._(
      raw: raw,
      isEncoded: false,
      primaryUrl: raw,
      deepLinkUrl: null,
      title: null,
      subtitle: null,
    );
  }

  String tileText({required String? wallId}) {
    if (!isEncoded) {
      final String normalizedWallId = wallId?.trim() ?? '';
      return normalizedWallId.isEmpty ? 'Wall Link' : 'Prism ($normalizedWallId)';
    }
    final String header = title?.trim() ?? '';
    final String tail = subtitle?.trim() ?? '';
    if (header.isEmpty) {
      return tail;
    }
    return tail.isEmpty ? header : '$header - $tail';
  }
}
