import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';

bool get hideSetWallpaperUi => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// The Lock Screen Depth Effect exists only on iOS, so depth badges and filters show only there.
bool get showDepthEffectUi => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

String wallpaperSavedMessage(AppLocalizations l10n) =>
    hideSetWallpaperUi ? l10n.coreWallpaperSavedPhotos : l10n.coreWallpaperDownloadedPictures;
