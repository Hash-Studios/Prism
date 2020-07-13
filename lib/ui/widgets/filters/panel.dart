import 'package:flutter/material.dart';
import 'package:Prism/ui/widgets/filters/hue.dart';
import 'package:Prism/ui/widgets/filters/exposure.dart';

class FilterPanel extends StatefulWidget {
  Color accent;
  Color exposure;
  FilterPanel({@required this.accent, @required this.exposure});
  @override
  _FilterPanelState createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  double position = 150;
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
                  widget.accent = newColor;
                  print(widget.accent);
                  position = 150;
                });
              },
            ),
            ExposurePicker(
              position: position,
              width: 300,
              onExposureChanged: (newColor) {
                setState(() {
                  widget.exposure = newColor;
                  print(widget.exposure);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
