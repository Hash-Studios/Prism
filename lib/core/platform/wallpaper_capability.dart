import 'package:flutter/foundation.dart';

bool get hideSetWallpaperUi => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

String get wallpaperSavedMessage => hideSetWallpaperUi ? 'Saved to Photos.' : 'Wall downloaded in Pictures/Prism!';
