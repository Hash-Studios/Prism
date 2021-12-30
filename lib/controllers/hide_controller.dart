import 'package:flutter/cupertino.dart';
import 'package:prism/services/hide_service.dart';
import 'package:prism/services/locator.dart';

class HideController extends ChangeNotifier {
  final HideService _hideService = locator<HideService>();

  bool get hidden => _hideService.hidden;

  void showBar() {
    _hideService.showBar();
    notifyListeners();
  }

  void hideBar() {
    _hideService.hideBar();
    notifyListeners();
  }
}
