import 'package:flutter/foundation.dart';

bool get hideSetWallpaperUi => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
