import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:flutter/material.dart';

class App {
  late BuildContext _context;
  late double _height;
  late double _width;
  late double _heightPadding;
  late double _widthPadding;

  App(BuildContext context) {
    _context = context;
    final MediaQueryData queryData = MediaQuery.of(_context);
    _height = queryData.size.height / 100.0;
    _width = queryData.size.width / 100.0;
    _heightPadding = _height - ((queryData.padding.top + queryData.padding.bottom) / 100.0);
    _widthPadding = _width - (queryData.padding.left + queryData.padding.right) / 100.0;
  }

  double appHeight(double v) {
    return _height * v;
  }

  double appWidth(double v) {
    return _width * v;
  }

  double appVerticalPadding(double v) {
    return _heightPadding * v;
  }

  double appHorizontalPadding(double v) {
    return _widthPadding * v;
  }
}

class Colors {
  static const Color _mainColor = Color(0xFFFFFFFF);
  static const Color _secondColor = Color(0xFFEDEDED);
  static const Color _accentColor = Color(0xFF2F2F2F);
  static const Color _mainDarkColor = Color(0xFF000000);
  static const Color _secondDarkColor = Color(0xFF2F2F2F);
  static const Color _accentDarkColor = Color(0xFFF0F0F0);
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();

  Color get _mainAccentColor => Color(_settingsLocal.get<int>("systemOverlayColor", defaultValue: 0xFFFFFFFF));

  Color mainColor(double opacity) {
    return _mainColor.withValues(alpha: opacity);
  }

  Color secondColor(double opacity) {
    return _secondColor.withValues(alpha: opacity);
  }

  Color accentColor(double opacity) {
    return _accentColor.withValues(alpha: opacity);
  }

  Color mainDarkColor(double opacity) {
    return _mainDarkColor.withValues(alpha: opacity);
  }

  Color secondDarkColor(double opacity) {
    return _secondDarkColor.withValues(alpha: opacity);
  }

  Color accentDarkColor(double opacity) {
    return _accentDarkColor.withValues(alpha: opacity);
  }

  Color mainAccentColor(double opacity) {
    return _mainAccentColor.withValues(alpha: opacity);
  }
}
