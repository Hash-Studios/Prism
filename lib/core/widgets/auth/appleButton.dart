import 'dart:io';

import 'package:Prism/auth/apple_auth.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:flutter/material.dart';

final AppleAuth _appleAuth = AppleAuth();

class AppleButton extends StatefulWidget {
  final bool login;
  final String text;
  const AppleButton({required this.login, required this.text, super.key});

  @override
  _AppleButtonState createState() => _AppleButtonState();
}

class _AppleButtonState extends State<AppleButton> {
  bool loader = false;
  bool isError = false;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
      child: Container(
        decoration: widget.login
            ? BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4)),
                ],
                borderRadius: BorderRadius.circular(500),
              )
            : BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(500),
              ),
        child: MaterialButton(
          colorBrightness: Brightness.dark,
          padding: EdgeInsets.zero,
          shape: const StadiumBorder(),
          onPressed: () {
            _appleAuth.signInWithApple().catchError((e) {
              if (!mounted) return '';
              setState(() {
                isError = true;
              });
              final navigator = Navigator.of(context);
              Future.delayed(const Duration(milliseconds: 500)).then((_) {
                if (mounted) navigator.pop();
              });
              return '';
            });
          },
          child: SizedBox(
            width: width * 0.75,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.apple, color: Colors.white, size: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: widget.login
                          ? Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.white)
                          : Theme.of(context).textTheme.labelLarge!.copyWith(color: config.Colors().mainColor(1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
