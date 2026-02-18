import 'package:flutter/material.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({super.key, this.appBar, required this.body, this.backgroundColor, this.safeArea = true});

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final Widget content = safeArea ? SafeArea(child: body) : body;
    return Scaffold(appBar: appBar, backgroundColor: backgroundColor ?? Theme.of(context).primaryColor, body: content);
  }
}
