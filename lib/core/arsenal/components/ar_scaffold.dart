import 'package:Prism/core/arsenal/theme.dart';
import 'package:flutter/material.dart';

class ArScaffold extends StatelessWidget {
  const ArScaffold({super.key, required this.child, this.extendBodyBehindAppBar = true, this.appBar});

  final Widget child;
  final bool extendBodyBehindAppBar;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: arsenalDarkTheme,
      child: Scaffold(extendBodyBehindAppBar: extendBodyBehindAppBar, appBar: appBar, body: child),
    );
  }
}
