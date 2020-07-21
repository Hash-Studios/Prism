import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2),
      width: double.infinity,
      color: Colors.red,
      child: Text(
        "No Internet",
        style: TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFamily: 'Proxima Nova',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
