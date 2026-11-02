import 'package:flutter/foundation.dart';

String? rewardedAdUnitId({required bool isRelease, required TargetPlatform platform, required String iosAdUnitId}) {
  if (isRelease) {
    if (platform == TargetPlatform.android) return 'ca-app-pub-4649644680694757/3358009164';
    final String configuredId = iosAdUnitId.trim();
    return configuredId.isEmpty ? null : configuredId;
  }
  return platform == TargetPlatform.android
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';
}
