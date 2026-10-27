import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    swiftOptions: SwiftOptions(errorClassName: 'PrismShareError'),
    kotlinOptions: KotlinOptions(errorClassName: 'PrismShareFlutterError'),
  ),
)
@HostApi()
abstract class PrismShareHostApi {
  bool canShareInstagramStory(InstagramStoryTarget target);
  @async
  bool shareInstagramStory(InstagramStoryTarget target, String imagePath);
}

/// Built in Dart by `instagramStoryTarget`, so the Meta contract is tested once and native code only executes it.
class InstagramStoryTarget {
  final String appId;
  final String iosUrl;
  final String iosPasteboardKey;
  final String androidAction;
  final String androidPackage;
  final String androidAppIdExtra;
  final String mimeType;

  InstagramStoryTarget({
    required this.appId,
    required this.iosUrl,
    required this.iosPasteboardKey,
    required this.androidAction,
    required this.androidPackage,
    required this.androidAppIdExtra,
    required this.mimeType,
  });
}
