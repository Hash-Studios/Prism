import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/domain/repositories/smart_folders_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:injectable/injectable.dart';

typedef SmartFolderCallable = Future<Object?> Function(String name, Map<String, Object?> data);

SmartFolderFailure smartFolderFailure(Object error) {
  if (error is! FirebaseFunctionsException) return SmartFolderFailure('$error');
  final String message = error.message ?? '';
  final SmartFolderRefusal? refusal = switch (error.code) {
    'resource-exhausted' => SmartFolderRefusal.limit,
    'failed-precondition' when message == 'account' => SmartFolderRefusal.account,
    'invalid-argument' => SmartFolderRefusal.rules,
    _ => null,
  };
  return SmartFolderFailure(message.isEmpty ? error.code : message, refusal: refusal, code: error.code);
}

SmartPreview smartPreviewFromJson(Object? data) {
  final Map<Object?, Object?> map = data is Map ? data : const <Object?, Object?>{};
  final Object? walls = map['walls'];
  return SmartPreview(
    count: map['count'] is num ? (map['count']! as num).toInt() : 0,
    more: map['more'] == true,
    walls: <SmartPreviewWall>[
      if (walls is List)
        for (final Object? wall in walls)
          if (wall is Map && parseString(wall['thumb']).isNotEmpty)
            SmartPreviewWall(
              id: parseString(wall['id']),
              docId: parseString(wall['docId']),
              thumb: parseString(wall['thumb']),
            ),
    ],
  );
}

@LazySingleton(as: SmartFoldersRepository)
class SmartFoldersRepositoryImpl implements SmartFoldersRepository {
  SmartFoldersRepositoryImpl({@ignoreParam SmartFolderCallable? callFunction}) : _call = callFunction ?? _callFunction;

  final SmartFolderCallable _call;

  static Future<Object?> _callFunction(String name, Map<String, Object?> data) async =>
      (await appFunctions.httpsCallable(name).call<Object?>(data)).data;

  List<Map<String, String>> _rules(List<SmartRule> rules) => <Map<String, String>>[
    for (final SmartRule rule in rules) rule.toJson(),
  ];

  Future<Result<T>> _guard<T>(String what, Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } catch (error, stackTrace) {
      logger.w('Smart folders: could not $what', tag: 'Folders', error: error, stackTrace: stackTrace);
      return Result.error(smartFolderFailure(error));
    }
  }

  @override
  Future<Result<SmartPreview>> preview(List<SmartRule> rules) => _guard(
    'preview',
    () async => smartPreviewFromJson(await _call('previewSmartFolder', <String, Object?>{'rules': _rules(rules)})),
  );

  @override
  Future<Result<({String folderId, int count})>> create({required String name, required List<SmartRule> rules}) =>
      _guard('create', () async {
        final Object? data = await _call('createSmartFolder', <String, Object?>{'name': name, 'rules': _rules(rules)});
        final Map<Object?, Object?> map = data is Map ? data : const <Object?, Object?>{};
        final String folderId = parseString(map['folderId']);
        if (folderId.isEmpty) throw StateError('createSmartFolder returned no folder id');
        return (folderId: folderId, count: map['count'] is num ? (map['count']! as num).toInt() : 0);
      });

  @override
  Future<Result<int>> updateRules(String folderId, List<SmartRule> rules) => _guard('update rules', () async {
    final Object? data = await _call('updateSmartFolderRules', <String, Object?>{
      'folderId': folderId,
      'rules': _rules(rules),
    });
    final Object? count = data is Map ? data['count'] : null;
    return count is num ? count.toInt() : 0;
  });
}
