import 'package:flutter/material.dart';
import 'package:cloud_toast/cloud_toast.dart';
// import 'package:prism/services/logger.dart';

class ToastController {
  late final CloudToast cloudToast;

  void init(BuildContext context) {
    try {
      cloudToast = CloudToast();
      cloudToast.init(context);
    } catch (e, s) {
      // logger.e(e, e, s);
    }
  }

  void messageToast(String msg) {
    cloudToast.messageToast(msg);
  }
}
