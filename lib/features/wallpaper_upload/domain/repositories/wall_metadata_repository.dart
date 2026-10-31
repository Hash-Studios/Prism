import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';

abstract class WallMetadataRepository {
  Future<WallMetadataSnapshot> load(String wallDocId, {required bool approved});

  Future<WallMetadataSnapshot> updatePending(
    String wallDocId,
    PendingWallMetadata metadata, {
    required WallMetadataSnapshot expected,
  });

  Future<WallMetadataSnapshot> editApproved(
    String wallDocId,
    WallTextMetadata metadata, {
    required String expectedRevision,
    required String operationId,
  });

  Future<WallMetadataAuditPage> listEdits(String wallDocId, {String? cursor});

  Future<WallMetadataSnapshot> revert(
    String wallDocId,
    String auditId, {
    required String expectedRevision,
    required String operationId,
  });

  /// Only a verified server receipt can produce a context. A raw wall pointer is never sufficient.
  Future<Map<String, WallResubmissionContext>> resubmissionContexts(List<String> wallDocIds);
}
