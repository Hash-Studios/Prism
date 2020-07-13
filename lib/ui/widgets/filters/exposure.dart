import 'package:flutter/material.dart';

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
  Color color;
  final Function onExposureChanged;
  ExposurePicker(
      {@required this.width,
      @required this.color,
      @required this.onExposureChanged});
  @override
  _ExposurePickerState createState() => _ExposurePickerState();
}

class _ExposurePickerState extends State<ExposurePicker> {
  final List<Color> _colors = [
    Color.fromARGB(255, 255, 0, 0),
    Color.fromARGB(255, 255, 128, 0),
    Color.fromARGB(255, 255, 255, 0),
    Color.fromARGB(255, 128, 255, 0),
    Color.fromARGB(255, 0, 255, 0),
    Color.fromARGB(255, 0, 255, 128),
    Color.fromARGB(255, 0, 255, 255),
    Color.fromARGB(255, 0, 128, 255),
    Color.fromARGB(255, 0, 0, 255),
    Color.fromARGB(255, 127, 0, 255),
    Color.fromARGB(255, 255, 0, 255),
    Color.fromARGB(255, 255, 0, 127),
    Color.fromARGB(255, 128, 128, 128),
  ];
  double _colorSliderPosition = 0;
  double _shadeSliderPosition;
  @override
  initState() {
    super.initState();
    widget.color = _calculateSelectedColor(_colorSliderPosition);
    _shadeSliderPosition = widget.width / 2; //center the shader selector
    _shadedColor = _calculateShadedColor(_shadeSliderPosition);
  }

  _shadeChangeHandler(double position) {
    //handle out of bounds gestures
    if (position > widget.width) position = widget.width;
    if (position < 0) position = 0;
    setState(() {
      _shadeSliderPosition = position;
      _shadedColor = _calculateShadedColor(_shadeSliderPosition);
      // print(
      // "r: ${_shadedColor.red}, g: ${_shadedColor.green}, b: ${_shadedColor.blue}");
    });
    widget.onExposureChanged(_shadedColor);
  }

  Color _calculateShadedColor(double position) {
    double ratio = position / widget.width;
    if (ratio > 0.5) {
      //Calculate new color (values converge to 255 to make the color lighter)
      int redVal = widget.color.red != 255
          ? (widget.color.red + (255 - widget.color.red) * (ratio - 0.5) / 0.5)
              .round()
          : 255;
      int greenVal = widget.color.green != 255
          ? (widget.color.green +
                  (255 - widget.color.green) * (ratio - 0.5) / 0.5)
              .round()
          : 255;
      int blueVal = widget.color.blue != 255
          ? (widget.color.blue +
                  (255 - widget.color.blue) * (ratio - 0.5) / 0.5)
              .round()
          : 255;
      return Color.fromARGB(255, redVal, greenVal, blueVal);
    } else if (ratio < 0.5) {
      //Calculate new color (values converge to 0 to make the color darker)
      int redVal =
          widget.color.red != 0 ? (widget.color.red * ratio / 0.5).round() : 0;
      int greenVal = widget.color.green != 0
          ? (widget.color.green * ratio / 0.5).round()
          : 0;
      int blueVal = widget.color.blue != 0
          ? (widget.color.blue * ratio / 0.5).round()
          : 0;
      return Color.fromARGB(255, redVal, greenVal, blueVal);
    } else {
      //return the base color
      return widget.color;
    }
  }

  Color _calculateSelectedColor(double position) {
    //determine color
    double positionInColorArray =
        (position / widget.width * (_colors.length - 1));
    // print(positionInColorArray);
    int index = positionInColorArray.truncate();
    // print(index);
    double remainder = positionInColorArray - index;
    if (remainder == 0.0) {
      widget.color = _colors[index];
    } else {
      //calculate new color
      int redValue = _colors[index].red == _colors[index + 1].red
          ? _colors[index].red
          : (_colors[index].red +
                  (_colors[index + 1].red - _colors[index].red) * remainder)
              .round();
      int greenValue = _colors[index].green == _colors[index + 1].green
          ? _colors[index].green
          : (_colors[index].green +
                  (_colors[index + 1].green - _colors[index].green) * remainder)
              .round();
      int blueValue = _colors[index].blue == _colors[index + 1].blue
          ? _colors[index].blue
          : (_colors[index].blue +
                  (_colors[index + 1].blue - _colors[index].blue) * remainder)
              .round();
      widget.color = Color.fromARGB(255, redValue, greenValue, blueValue);
    }
    return widget.color;
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
        // Container(
        //   height: 50,
        //   width: 50,
        //   decoration: BoxDecoration(
        //     color: _shadedColor,
        //     shape: BoxShape.circle,
        //   ),
        // )
      ],
    );
  }
}
