// ignore_for_file: constant_identifier_names

library cloud_toast;

import 'dart:async';

import 'package:flutter/material.dart';

/// ToastPosition
/// Used to define the position of the Toast on the screen
enum ToastPosition {
  TOP,
  BOTTOM,
  CENTER,
  TOP_LEFT,
  TOP_RIGHT,
  BOTTOM_LEFT,
  BOTTOM_RIGHT,
  CENTER_LEFT,
  CENTER_RIGHT,
  SNACKBAR
}

typedef PositionedToastBuilder = Widget Function(
    BuildContext context, Widget child);

/// Runs on dart side this has no interaction with the Native Side
/// Works with all platforms just in two lines of code
/// final cloudToast = CloudToast().init(context)
/// cloudToast.show(child)
///
class CloudToast {
  BuildContext? context;

  static final CloudToast _instance = CloudToast._internal();

  /// Prmary Constructor for CloudToast
  factory CloudToast() {
    return _instance;
  }

  /// Take users Context and saves to avariable
  CloudToast init(BuildContext context) {
    _instance.context = context;
    return _instance;
  }

  CloudToast._internal();

  OverlayEntry? _entry;
  final List<_ToastEntry> _overlayQueue = [];
  Timer? _timer;

  /// Internal function which handles the adding
  /// the overlay to the screen
  ///
  _showOverlay() {
    if (_overlayQueue.isEmpty) {
      _entry = null;
      return;
    }
    _ToastEntry _toastEntry = _overlayQueue.removeAt(0);
    _entry = _toastEntry.entry;
    if (context == null) {
      throw ("Error: Context is null, Please call init(context) before showing toast.");
    }
    Overlay.of(context!)!.insert(_entry!);

    _timer = Timer(_toastEntry.duration!, () {
      Future.delayed(const Duration(milliseconds: 360), () {
        removeCustomToast();
      });
    });
  }

  /// If any active toast present
  /// call removeCustomToast to hide the toast immediately
  removeCustomToast() {
    _timer?.cancel();
    _timer = null;
    if (_entry != null) _entry!.remove();
    _entry = null;
    _showOverlay();
  }

  /// CloudToast maintains a queue for every toast
  /// if we called showToast for 3 times we add to queue
  /// and show them one after another
  ///
  /// call removeCustomToast to hide the toast immediately
  removeQueuedCustomToasts() {
    _timer?.cancel();
    _timer = null;
    _overlayQueue.clear();
    if (_entry != null) _entry!.remove();
    _entry = null;
  }

  void messageToast(String msg) {
    manualToast(
      child: Center(child: Text(msg)),
      width: MediaQuery.of(context!).size.width,
      height: MediaQuery.of(context!).padding.top + kToolbarHeight + 40,
      top: 0,
      left: 0,
    );
  }

  void errorToast(
    dynamic message, [
    dynamic error,
    StackTrace? trace,
  ]) {
    manualToast(
      child: Center(child: Text(message)),
      width: MediaQuery.of(context!).size.width,
      height: MediaQuery.of(context!).padding.top + kToolbarHeight + 40,
      top: 0,
      left: 0,
      color: const Color(0xffae2727),
    );
  }

  void manualToast({
    required Widget child,
    double? width,
    double? height,
    Color color = const Color(0xff27ae61),
    double? top,
    double? bottom,
    double? left,
    double? right,
    ToastPosition? toastPosition = ToastPosition.TOP,
    Duration? toastDuration = const Duration(seconds: 4),
    Duration? fadeDuration = const Duration(milliseconds: 350),
  }) {
    if (context == null) {
      throw ("Error: Context is null, Please call init(context) before showing toast.");
    }
    final Widget toast = Container(
      child: child,
      width: width,
      height: height,
      color: color,
    );
    showToast(
      child: toast,
      positionedToastBuilder: (context, child) => Positioned(
        child: child,
        top: top,
        left: left,
        bottom: bottom,
        right: right,
      ),
      gravity: toastPosition,
      toastDuration: toastDuration,
      fadeDuration: fadeDuration,
    );
  }

  /// showToast accepts all the required paramenters and prepares the child
  /// calls _showOverlay to display toast
  ///
  /// Paramenter [child] is requried
  /// fadeDuration default is 350 milliseconds
  void showToast({
    required Widget child,
    PositionedToastBuilder? positionedToastBuilder,
    Duration? toastDuration,
    ToastPosition? gravity,
    Duration? fadeDuration = const Duration(milliseconds: 350),
  }) {
    if (context == null) {
      throw ("Error: Context is null, Please call init(context) before showing toast.");
    }
    Widget newChild = _ToastStateFul(
        child, toastDuration ?? const Duration(seconds: 2),
        fadeDuration: fadeDuration);

    /// Check for keyboard open
    /// If open will ignore the gravity bottom and change it to center
    if (gravity == ToastPosition.BOTTOM) {
      if (MediaQuery.of(context!).viewInsets.bottom != 0) {
        gravity = ToastPosition.CENTER;
      }
    }

    OverlayEntry newEntry = OverlayEntry(builder: (context) {
      if (positionedToastBuilder != null) {
        return positionedToastBuilder(context, newChild);
      }
      return _getPostionWidgetBasedOnGravity(newChild, gravity);
    });

    _overlayQueue.add(_ToastEntry(
        entry: newEntry,
        duration: toastDuration ?? const Duration(seconds: 2)));
    if (_timer == null) _showOverlay();
  }

  /// _getPostionWidgetBasedOnGravity generates [Positioned] [Widget]
  /// based on the gravity  [ToastPosition] provided by the user in
  /// [showToast]
  _getPostionWidgetBasedOnGravity(Widget child, ToastPosition? gravity) {
    switch (gravity) {
      case ToastPosition.TOP:
        return Positioned(top: 100.0, left: 24.0, right: 24.0, child: child);
      case ToastPosition.TOP_LEFT:
        return Positioned(top: 100.0, left: 24.0, child: child);
      case ToastPosition.TOP_RIGHT:
        return Positioned(top: 100.0, right: 24.0, child: child);
      case ToastPosition.CENTER:
        return Positioned(
            top: 50.0, bottom: 50.0, left: 24.0, right: 24.0, child: child);
      case ToastPosition.CENTER_LEFT:
        return Positioned(top: 50.0, bottom: 50.0, left: 24.0, child: child);
      case ToastPosition.CENTER_RIGHT:
        return Positioned(top: 50.0, bottom: 50.0, right: 24.0, child: child);
      case ToastPosition.BOTTOM_LEFT:
        return Positioned(bottom: 50.0, left: 24.0, child: child);
      case ToastPosition.BOTTOM_RIGHT:
        return Positioned(bottom: 50.0, right: 24.0, child: child);
      case ToastPosition.SNACKBAR:
        return Positioned(
            bottom: MediaQuery.of(context!).viewInsets.bottom,
            left: 0,
            right: 0,
            child: child);
      case ToastPosition.BOTTOM:
      default:
        return Positioned(bottom: 50.0, left: 24.0, right: 24.0, child: child);
    }
  }
}

/// internal class [_ToastEntry] which maintains
/// each [OverlayEntry] and [Duration] for every toast user
/// triggered
class _ToastEntry {
  final OverlayEntry? entry;
  final Duration? duration;

  _ToastEntry({this.entry, this.duration});
}

/// internal [StatefulWidget] which handles the show and hide
/// animations for [FToast]
class _ToastStateFul extends StatefulWidget {
  const _ToastStateFul(this.child, this.duration,
      {Key? key, this.fadeDuration = const Duration(milliseconds: 350)})
      : super(key: key);

  final Widget child;
  final Duration duration;
  final Duration? fadeDuration;

  @override
  ToastStateFulState createState() => ToastStateFulState();
}

/// State for [_ToastStateFul]
class ToastStateFulState extends State<_ToastStateFul>
    with SingleTickerProviderStateMixin {
  /// Start the showing animations for the toast
  showIt() {
    _animationController!.forward();
  }

  /// Start the hidding animations for the toast
  hideIt() {
    _animationController!.reverse();
    _timer?.cancel();
  }

  /// Controller to start and hide the animation
  AnimationController? _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _timer;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
      reverseDuration: widget.fadeDuration,
    );
    _fadeAnimation = CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeInCubic,
        reverseCurve: Curves.easeOutCubic);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: const Offset(0, 0))
            .animate(_fadeAnimation);
    super.initState();

    showIt();
    _timer = Timer(widget.duration, () {
      hideIt();
    });
  }

  @override
  void deactivate() {
    _timer?.cancel();
    _animationController!.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
