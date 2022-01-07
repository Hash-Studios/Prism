import 'package:flutter/material.dart';
import 'package:prism/model/settings/wall_display_mode.dart';
import 'package:prism/model/settings/wall_thumb_quality.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/settings_service.dart';

class SettingsController extends ChangeNotifier {
  final SettingsService _settingsService = locator<SettingsService>();
  WallDisplayMode get wallDisplayMode => _settingsService.wallDisplayMode;
  set wallDisplayMode(WallDisplayMode value) {
    _settingsService.wallDisplayMode = value;
    notifyListeners();
  }

  WallThumbQuality get wallThumbQuality => _settingsService.wallThumbQuality;
  set wallThumbQuality(WallThumbQuality value) {
    _settingsService.wallThumbQuality = value;
    notifyListeners();
  }
}
