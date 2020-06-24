import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void successReg() {
  Fluttertoast.showToast(
    msg: "Successfully Registered!",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.green[400],
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void successLog() {
  Fluttertoast.showToast(
    msg: "Login Successful!",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.green[400],
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void successLogOut() {
  Fluttertoast.showToast(
    msg: "Log out Successful!",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.green[400],
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void validEmail() {
  Fluttertoast.showToast(
      msg: "Please enter valid email address!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      backgroundColor: Colors.red[400],
      fontSize: 16.0);
}

void codeSend(String msg) {
  Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      backgroundColor: Colors.green[400],
      fontSize: 16.0);
}

void noUser() {
  Fluttertoast.showToast(
      msg: "Sorry no user found with this email address!",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      backgroundColor: Colors.red[400],
      fontSize: 16.0);
}

void error(String msg) {
  Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    textColor: Colors.white,
    backgroundColor: Colors.red[400],
    fontSize: 16.0,
  );
}

void successPassReset() {
  Fluttertoast.showToast(
      msg: "Password Reset Successful!",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.green[400],
      textColor: Colors.white,
      fontSize: 16.0);
}

void timeout() {
  Fluttertoast.showToast(
    msg: "Connection Timeout Error!",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.red[400],
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void network() {
  Fluttertoast.showToast(
    msg: "Network Not Connected!",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.red[400],
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void successContact() {
  Fluttertoast.showToast(
    msg: "Message sent successfully!",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.green[400],
    textColor: Colors.white,
    fontSize: 16.0,
  );
  Fluttertoast.showToast(
    msg: "We will contact you shortly.",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void startDownload() {
  Fluttertoast.showToast(
      msg: "Starting Download",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green[400],
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      fontSize: 16.0);
}

void completedDownload() {
  Fluttertoast.showToast(
      msg: "Image Downloaded in Pictures/Prism!",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green[400],
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      fontSize: 16.0);
}

void shareWall() {
  Fluttertoast.showToast(
      msg: "Sharing link copied!",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green[400],
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      fontSize: 16.0);
}
