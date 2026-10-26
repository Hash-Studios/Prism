import 'dart:io';

import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:flutter/foundation.dart';

/// iOS Live Activities. Every call is a no-op on other platforms and never throws.
class LiveActivityChannel {
  const LiveActivityChannel._();

  @visibleForTesting
  static PrismLiveActivityHostApi api = PrismLiveActivityHostApi();

  @visibleForTesting
  static bool Function() isSupportedPlatform = () => !kIsWeb && Platform.isIOS;

  static Future<AiGenerationActivity?> startAiGeneration(AiActivityRequest request) async {
    if (!isSupportedPlatform()) return null;
    try {
      final String? id = await api.startAiGeneration(request);
      if (id == null || id.isEmpty) return null;
      return AiGenerationActivity._(id);
    } on Object {
      return null;
    }
  }
}

/// One running AI generation activity. The first of finish, fail or cancel wins; later calls do nothing.
class AiGenerationActivity {
  AiGenerationActivity._(this.id);

  final String id;
  bool _settled = false;

  Future<void> finish(String imageUrl) => _settle(() => LiveActivityChannel.api.finishAiGeneration(id, imageUrl));

  Future<void> fail(String detail) => _settle(() => LiveActivityChannel.api.failAiGeneration(id, detail));

  Future<void> cancel() => _settle(() => LiveActivityChannel.api.cancelAiGeneration(id));

  Future<void> _settle(Future<void> Function() call) async {
    if (_settled) return;
    _settled = true;
    try {
      await call();
    } on Object {
      return;
    }
  }
}
