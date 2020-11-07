import 'package:Prism/main.dart' as main;
import 'package:flutter/material.dart';

class App {
  BuildContext _context;
  double _height;
  double _width;
  double _heightPadding;
  double _widthPadding;

  App(BuildContext _context) {
    this._context = _context;
    final MediaQueryData _queryData = MediaQuery.of(this._context);
    _height = _queryData.size.height / 100.0;
    _width = _queryData.size.width / 100.0;
    _heightPadding = _height -
        ((_queryData.padding.top + _queryData.padding.bottom) / 100.0);
    _widthPadding =
        _width - (_queryData.padding.left + _queryData.padding.right) / 100.0;
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
  static const Color _mainDarkColor = Color(0xFF181818);
  static const Color _secondDarkColor = Color(0xFF2F2F2F);
  static const Color _accentDarkColor = Color(0xFFF0F0F0);
  final Color _mainAccentColor =
      Color(main.prefs.get("mainAccentColor") as int);

  Color mainColor(double opacity) {
    return _mainColor.withOpacity(opacity);
  }

  Color secondColor(double opacity) {
    return _secondColor.withOpacity(opacity);
  }

  Color accentColor(double opacity) {
    return _accentColor.withOpacity(opacity);
  }

  Color mainDarkColor(double opacity) {
    return _mainDarkColor.withOpacity(opacity);
  }

  Color secondDarkColor(double opacity) {
    return _secondDarkColor.withOpacity(opacity);
  }

  Color accentDarkColor(double opacity) {
    return _accentDarkColor.withOpacity(opacity);
  }

  Color mainAccentColor(double opacity) {
    return _mainAccentColor.withOpacity(opacity);
  }
}
