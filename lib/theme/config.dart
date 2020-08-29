import 'package:flutter/material.dart';

class App {
  BuildContext _context;
  double _height;
  double _width;
  double _heightPadding;
  double _widthPadding;

  App(_context) {
    this._context = _context;
    MediaQueryData _queryData = MediaQuery.of(this._context);
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
  Color _mainColor = Color(0xFFFFFFFF);
  Color _secondColor = Color(0xFFEDEDED);
  Color _accentColor = Color(0xFF2F2F2F);
  Color _mainDarkColor = Color(0xFF181818);
  Color _secondDarkColor = Color(0xFF2F2F2F);
  Color _accentDarkColor = Color(0xFFF0F0F0);

  Color mainColor(double opacity) {
    return this._mainColor.withOpacity(opacity);
  }

  Color secondColor(double opacity) {
    return this._secondColor.withOpacity(opacity);
  }

  Color accentColor(double opacity) {
    return this._accentColor.withOpacity(opacity);
  }

  Color mainDarkColor(double opacity) {
    return this._mainDarkColor.withOpacity(opacity);
  }

  Color secondDarkColor(double opacity) {
    return this._secondDarkColor.withOpacity(opacity);
  }

  Color accentDarkColor(double opacity) {
    return this._accentDarkColor.withOpacity(opacity);
  }
}
