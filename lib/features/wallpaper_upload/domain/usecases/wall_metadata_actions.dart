import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/repositories/wall_metadata_repository.dart';

class WallMetadataActions {
  const WallMetadataActions(this.repository);

  final WallMetadataRepository repository;

  Future<WallMetadataSnapshot> load(String id, {required bool approved}) => repository.load(id, approved: approved);

  Future<WallMetadataSnapshot> save(
    String id,
    PendingWallMetadata metadata, {
    required WallMetadataSnapshot expected,
    required String operationId,
  }) => expected.approved
      ? repository.editApproved(id, metadata.text, expectedRevision: expected.revision, operationId: operationId)
      : repository.updatePending(id, metadata, expected: expected);

  Future<WallMetadataAuditPage> listEdits(String id, {String? cursor}) => repository.listEdits(id, cursor: cursor);

  Future<WallMetadataSnapshot> revert(
    String id,
    String auditId, {
    required String revision,
    required String operationId,
  }) => repository.revert(id, auditId, expectedRevision: revision, operationId: operationId);

  Future<Map<String, WallResubmissionContext>> contexts(List<String> ids) => repository.resubmissionContexts(ids);
}
