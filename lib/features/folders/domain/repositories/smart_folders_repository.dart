import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';

/// One wall in a smart folder preview.
final class SmartPreviewWall {
  const SmartPreviewWall({required this.id, required this.docId, required this.thumb});

  final String id;
  final String docId;
  final String thumb;
}

/// The newest matches of a rule set. [count] stops at the fill size, and [more] says there are more than [count].
final class SmartPreview {
  const SmartPreview({required this.count, required this.more, required this.walls});

  final int count;
  final bool more;
  final List<SmartPreviewWall> walls;
}

enum SmartFolderRefusal { limit, account, rules }

class SmartFolderFailure extends Failure {
  const SmartFolderFailure(super.message, {this.refusal, super.code});

  final SmartFolderRefusal? refusal;
}

/// Smart folders through the server callables. The client never writes their items or their rule index.
abstract class SmartFoldersRepository {
  Future<Result<SmartPreview>> preview(List<SmartRule> rules);

  /// Creates the folder and fills it with the newest matches. Returns its id and its item count.
  Future<Result<({String folderId, int count})>> create({required String name, required List<SmartRule> rules});

  /// Replaces the rules and fills the folder again. Returns the item count.
  Future<Result<int>> updateRules(String folderId, List<SmartRule> rules);
}
