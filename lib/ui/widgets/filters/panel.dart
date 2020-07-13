import 'package:flutter/material.dart';
import 'package:Prism/ui/widgets/filters/hue.dart';
import 'package:Prism/ui/widgets/filters/exposure.dart';

class FilterPanel extends StatefulWidget {
  @override
  _FilterPanelState createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  Color color = Colors.white;
  Color finalColor = Colors.white;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
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
              onHueChanged: (newColor) {
                setState(() {
                  color = newColor;
                  print(color);
                });
              },
            ),
            ExposurePicker(
              width: 300,
              color: color,
              onExposureChanged: (newColor) {
                setState(() {
                  finalColor = newColor;
                  print(finalColor);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
