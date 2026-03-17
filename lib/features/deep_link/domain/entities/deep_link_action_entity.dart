import 'package:Prism/core/wallpaper/wallpaper_source.dart';

sealed class DeepLinkActionEntity {
  const DeepLinkActionEntity({required this.rawUri});

  final String rawUri;
}

final class ShareLinkIntent extends DeepLinkActionEntity {
  const ShareLinkIntent({
    required this.wallId,
    required this.source,
    required this.wallpaperUrl,
    required this.thumbnailUrl,
    required super.rawUri,
  });

  final String wallId;
  final WallpaperSource source;
  final String wallpaperUrl;
  final String thumbnailUrl;
}

final class UserLinkIntent extends DeepLinkActionEntity {
  const UserLinkIntent({required this.profileIdentifier, required super.rawUri});

  final String profileIdentifier;
}

final class SetupLinkIntent extends DeepLinkActionEntity {
  const SetupLinkIntent({required this.setupName, required this.thumbnailUrl, required super.rawUri});

  final String setupName;
  final String thumbnailUrl;
}

final class ReferLinkIntent extends DeepLinkActionEntity {
  const ReferLinkIntent({required this.inviterId, required super.rawUri});

  final String inviterId;
}

final class ShortCodeIntent extends DeepLinkActionEntity {
  const ShortCodeIntent({required this.code, required super.rawUri});

  final String code;
}

final class ReengagementIntent extends DeepLinkActionEntity {
  const ReengagementIntent({required this.sequence, required this.source, required this.userId, required super.rawUri});

  final int sequence;
  final String source;
  final String userId;
}

final class UnknownIntent extends DeepLinkActionEntity {
  const UnknownIntent({required super.rawUri});
}
