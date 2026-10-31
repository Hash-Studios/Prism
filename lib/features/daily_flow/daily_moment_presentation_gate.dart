import 'package:flutter/foundation.dart';

class DailyMomentPresentationGate extends ChangeNotifier {
  DailyMomentPresentationGate._();
  static final DailyMomentPresentationGate instance = DailyMomentPresentationGate._();
  bool _bootstrapReady = false;
  bool _deepLinkActive = false;
  bool _purchaseActive = false;
  bool _launchIntentsReady = false;
  bool get bootstrapReady => _bootstrapReady;
  bool get deepLinkActive => _deepLinkActive;
  bool get purchaseActive => _purchaseActive;
  bool get launchIntentsReady => _launchIntentsReady;
  bool get canShow => _bootstrapReady && _launchIntentsReady && !_deepLinkActive && !_purchaseActive;
  set launchIntentsReady(bool value) {
    if (_launchIntentsReady == value) return;
    _launchIntentsReady = value;
    notifyListeners();
  }

  set bootstrapReady(bool value) {
    if (_bootstrapReady == value) return;
    _bootstrapReady = value;
    notifyListeners();
  }

  set deepLinkActive(bool value) {
    if (_deepLinkActive == value) return;
    _deepLinkActive = value;
    notifyListeners();
  }

  set purchaseActive(bool value) {
    if (_purchaseActive == value) return;
    _purchaseActive = value;
    notifyListeners();
  }
}
