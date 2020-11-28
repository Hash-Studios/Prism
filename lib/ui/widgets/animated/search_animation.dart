import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class SearchAnimation extends StatefulWidget {
  @override
  _SearchAnimationState createState() => _SearchAnimationState();
}

class _SearchAnimationState extends State<SearchAnimation> {
  final riveFileName = 'assets/animations/prism_animations.riv';
  Artboard _artboard;
  RiveAnimationController _typingController;
  RiveAnimationController _idleController;
  bool _typing = false;

  @override
  void initState() {
    _loadRiveFile();
    super.initState();
  }

  Future<void> _loadRiveFile() async {
    final bytes = await rootBundle.load(riveFileName);
    final file = RiveFile();

    if (file.import(bytes)) {
      setState(() => _artboard = file.artboards[1]
        ..addController(
          _idleController = SimpleAnimation('idle'),
        ));
    }
  }

  void _typingChange(bool typingOn) {
    if (_typingController == null) {
      _artboard.addController(
        _typingController = SimpleAnimation('typing'),
      );
    }
    setState(() {
      _typingController.isActive = _typing = typingOn;
      _idleController.isActive = !typingOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _artboard != null
            ? SizedBox(
                height: 155,
                child: Rive(
                  artboard: _artboard,
                ),
              )
            : Container(),
        SizedBox(
          height: 50,
          width: 200,
          child: SwitchListTile(
            title: const Text('Wipers'),
            value: _typing,
            onChanged: _typingChange,
          ),
        ),
      ],
    );
  }
}
