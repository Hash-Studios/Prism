import 'package:flutter/material.dart';

class ColorProvider extends ChangeNotifier {
  Color hue = Colors.transparent;
  Color exposure = Colors.transparent;
  Color hueChanger(Color newHue) {
    this.hue = newHue;
    notifyListeners();
    return this.hue;
  }

  Color exposureChanger(Color newExposure) {
    this.exposure = newExposure;
    notifyListeners();
    return this.exposure;
  }
}
