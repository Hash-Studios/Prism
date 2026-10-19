import 'package:flutter/foundation.dart';

bool get hideSetWallpaperUi => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// The Lock Screen Depth Effect exists only on iOS, so depth badges and filters show only there.
bool get showDepthEffectUi => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

String get wallpaperSavedMessage => hideSetWallpaperUi ? 'Saved to Photos.' : 'Wall downloaded in Pictures/Prism!';
