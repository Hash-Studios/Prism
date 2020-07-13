import 'package:flutter/material.dart';
import 'package:Prism/data/color/provider/colorProvider.dart';
import 'package:provider/provider.dart';

Color _shadedColor;

class _SliderIndicatorPainter extends CustomPainter {
  final double position;
  _SliderIndicatorPainter(this.position);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
        Offset(position, size.height / 2), 6, Paint()..color = _shadedColor);
  }

  @override
  bool shouldRepaint(_SliderIndicatorPainter old) {
    return true;
  }
}

class ExposurePicker extends StatefulWidget {
  final double width;
  double position;
  ExposurePicker({
    @required this.width,
    @required this.position,
  });
  @override
  _ExposurePickerState createState() => _ExposurePickerState();
}

class _ExposurePickerState extends State<ExposurePicker> {
  final List<Color> _colors = [
    Color.fromARGB(255, 0, 0, 0),
    Color.fromARGB(255, 255, 255, 255),
  ];
  double _shadeSliderPosition;
  @override
  initState() {
    super.initState();
    _shadeSliderPosition = widget.position; //center the shader selector
    _shadedColor = _calculateShadedColor(_shadeSliderPosition);
  }

  _shadeChangeHandler(double position) {
    //handle out of bounds gestures
    if (position > widget.width) position = widget.width;
    if (position < 0) position = 0;
    setState(() {
      _shadeSliderPosition = position;
      _shadedColor = _calculateShadedColor(_shadeSliderPosition);
      widget.position = position;
      // print(
      // "r: ${_shadedColor.red}, g: ${_shadedColor.green}, b: ${_shadedColor.blue}");
    });
    Provider.of<ColorProvider>(context, listen: false)
        .exposureChanger(_shadedColor);
  }

  Color _calculateShadedColor(double position) {
    double ratio = position / widget.width;
    int val = (ratio * 255).round();
    return Color.fromARGB(255, val, val, val);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (DragStartDetails details) {
              // print("_-------------------------STARTED DRAG");
              _shadeChangeHandler(details.localPosition.dx);
            },
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              _shadeChangeHandler(details.localPosition.dx);
            },
            onTapDown: (TapDownDetails details) {
              _shadeChangeHandler(details.localPosition.dx);
            },
            //This outside padding makes it much easier to grab the slider because the gesture detector has
            // the extra padding to recognize gestures inside of
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Container(
                width: widget.width + 20,
                height: 20,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: widget.width,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(15),
                          // gradient: LinearGradient(colors: _colors),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 1,
                      left: _shadeSliderPosition + 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        height: 18,
                        width: 18,
                      ),
                    ),
                    CustomPaint(
                      painter:
                          _SliderIndicatorPainter(_shadeSliderPosition + 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
