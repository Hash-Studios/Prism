import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/quick_actions/domain/entities/quick_action_entity.dart';
import 'package:Prism/features/quick_actions/domain/repositories/quick_actions_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:quick_actions/quick_actions.dart';

@LazySingleton(as: QuickActionsRepository)
class QuickActionsRepositoryImpl implements QuickActionsRepository {
  QuickActionsRepositoryImpl(this._quickActions);

  final QuickActions _quickActions;
  final StreamController<QuickActionEntity> _controller = StreamController<QuickActionEntity>.broadcast();
  bool _isInitialized = false;

  QuickActionEntity _mapAction(String action) {
    switch (action) {
      case 'Personalized_Feed':
        return const QuickActionEntity(type: QuickActionType.followFeed, rawValue: 'Personalized_Feed');
      case 'Collections':
        return const QuickActionEntity(type: QuickActionType.collections, rawValue: 'Collections');
      case 'Downloads':
        return const QuickActionEntity(type: QuickActionType.downloads, rawValue: 'Downloads');
      default:
        return QuickActionEntity(type: QuickActionType.unknown, rawValue: action);
    }
  }

  @override
  Future<Result<void>> initialize() async {
    try {
      if (_isInitialized) {
        return Result.success(null);
      }
      _isInitialized = true;
      _quickActions.initialize((shortcutType) {
        _controller.add(_mapAction(shortcutType));
      });
      return Result.success(null);
    } catch (error) {
      return Result.error(UnknownFailure('Unable to initialize quick actions: $error'));
    }
  }

  @override
  Future<Result<void>> setDefaultShortcuts() async {
    try {
      await _quickActions.setShortcutItems(const <ShortcutItem>[
        ShortcutItem(type: 'Personalized_Feed', localizedTitle: 'For You', icon: '@drawable/ic_feed'),
        ShortcutItem(type: 'Collections', localizedTitle: 'Collections', icon: '@drawable/ic_collections'),
        ShortcutItem(type: 'Downloads', localizedTitle: 'Downloads', icon: '@drawable/ic_downloads'),
      ]);
      return Result.success(null);
    } catch (error) {
      return Result.error(UnknownFailure('Unable to set quick actions: $error'));
    }
  }

  @override
  Stream<QuickActionEntity> watchActions() => _controller.stream;
}
