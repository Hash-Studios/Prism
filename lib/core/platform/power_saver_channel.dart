import 'package:flutter/services.dart';

/// Reads Low Power Mode on iOS and battery saver on Android. Returns false when the phone cannot tell.
class PowerSaverChannel {
  const PowerSaverChannel();

  static const MethodChannel _channel = MethodChannel('prism/power');

  Future<bool> isOn() async {
    try {
      return await _channel.invokeMethod<bool>('lowPowerMode') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
