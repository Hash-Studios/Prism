import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    swiftOptions: SwiftOptions(errorClassName: 'PrismAppIconError'),
    kotlinOptions: KotlinOptions(errorClassName: 'PrismAppIconFlutterError'),
  ),
)
@HostApi()
abstract class PrismAppIconHostApi {
  @async
  bool setAppIcon(String? iconName);
  String? currentAppIcon();
  bool supportsAlternateIcons();
}
