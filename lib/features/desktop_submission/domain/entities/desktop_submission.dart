import 'package:Prism/core/firestore/firestore_document.dart';

enum DesktopSubmissionState { uploading, pending, approved, rejected }

class DesktopSubmission {
  const DesktopSubmission({
    required this.id,
    required this.wallDocId,
    required this.shareId,
    required this.creatorUid,
    required this.state,
    required this.reason,
    required this.thumbUrl,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.aspect,
    required this.wallThumb,
    required this.wallTitle,
    required this.creatorName,
    required this.replaces,
    required this.createdAt,
  });

  final String id;
  final String wallDocId;
  final String shareId;
  final String creatorUid;
  final DesktopSubmissionState state;
  final String? reason;
  final String thumbUrl;
  final int sourceWidth;
  final int sourceHeight;
  final String aspect;
  final String wallThumb;
  final String wallTitle;
  final String creatorName;
  final bool replaces;
  final DateTime? createdAt;

  /// Returns null when the document is not usable: no wall, no preview, or an unknown state.
  static DesktopSubmission? fromData(String id, Map<String, dynamic> data) {
    final Object? wallDocId = data['wallDocId'];
    final DesktopSubmissionState? state = DesktopSubmissionState.values.asNameMap()[data['state']];
    final Object? thumb = data['thumb'];
    if (wallDocId is! String || wallDocId.isEmpty || state == null) return null;
    if (thumb is! Map<String, dynamic> || thumb['url'] is! String) return null;
    final Object? source = data['source'];
    final Map<String, dynamic> sourceMap = source is Map<String, dynamic> ? source : const <String, dynamic>{};
    return DesktopSubmission(
      id: id,
      wallDocId: wallDocId,
      shareId: _text(data['shareId']),
      creatorUid: _text(data['creatorUid']),
      state: state,
      reason: _nullableText(data['reason']),
      thumbUrl: thumb['url'] as String,
      sourceWidth: _int(sourceMap['width']),
      sourceHeight: _int(sourceMap['height']),
      aspect: _text(sourceMap['aspect']),
      wallThumb: _text(data['wallThumb']),
      wallTitle: _text(data['wallTitle']),
      creatorName: _text(data['creatorName']),
      replaces: data['replaces'] == true,
      createdAt: FirestoreDocument(id, data).createdAt,
    );
  }

  static String _text(Object? value) => value is String ? value : '';

  static String? _nullableText(Object? value) => value is String && value.isNotEmpty ? value : null;

  static int _int(Object? value) => value is num ? value.toInt() : 0;
}
