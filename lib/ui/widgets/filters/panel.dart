import 'package:flutter/material.dart';
import 'package:Prism/ui/widgets/filters/hue.dart';
import 'package:Prism/ui/widgets/filters/exposure.dart';

class FilterPanel extends StatefulWidget {
  @override
  _FilterPanelState createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  double position = 150;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 100),
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(0xFF2F2F2F),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HuePicker(
                width: 300,
              ),
              ExposurePicker(
                position: position,
                width: 300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
