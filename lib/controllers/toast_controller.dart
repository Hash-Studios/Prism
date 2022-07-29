import 'package:flutter/material.dart';
import 'package:cloud_toast/cloud_toast.dart';
import 'package:prism/services/logger.dart';

class ToastController extends ChangeNotifier {
  late final CloudToast cloudToast;
  bool showMarqueeBar = false;
  String marqueeText = 'MARQUEE';

  void init(BuildContext context) {
    try {
      cloudToast = CloudToast();
      cloudToast.init(context);
    } catch (e, s) {
      logger.e(e, e, s);
    }
  }

  void messageToast(String msg) {
    cloudToast.messageToast(msg);
  }

  void errorToast(String msg) {
    cloudToast.errorToast(msg);
  }

  void _showMarqueeToolBar() {
    showMarqueeBar = true;
    notifyListeners();
  }

  void _hideMarqueeToolBar() {
    showMarqueeBar = false;
    notifyListeners();
  }

  void _setMarqueeText(String marquee) {
    marqueeText = marquee;
    notifyListeners();
  }

  Future<void> animateMarqueeToolBar({
    required String text,
    required Duration duration,
  }) async {
    _setMarqueeText(text);
    _showMarqueeToolBar();
    await Future.delayed(duration);
    _hideMarqueeToolBar();
    notifyListeners();
  }
}
