import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;

enum ThumbType { Low, High }

class ThumbModel extends ChangeNotifier {
  ThumbType thumbType = ThumbType.Low;

  ThumbModel(this.thumbType);

  toggleThumb() {
    if (this.thumbType == ThumbType.Low) {
      main.prefs.put("hqThumbs", true);
      this.thumbType = ThumbType.High;
      print(main.prefs.get("hqThumbs"));
      return notifyListeners();
    }

    if (this.thumbType == ThumbType.High) {
      main.prefs.put("hqThumbs", false);
      this.thumbType = ThumbType.Low;
      print(main.prefs.get("hqThumbs"));
      return notifyListeners();
    }
  }

  returnThumb() {
    return this.thumbType;
  }
}
