import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(swiftOptions: SwiftOptions(errorClassName: 'PrismLiveActivityError')))
class AiActivityRequest {
  AiActivityRequest({
    required this.prompt,
    required this.style,
    required this.accentArgb,
    required this.swatchArgb,
    required this.generatingTitle,
    required this.readyTitle,
    required this.failedTitle,
    required this.staleTitle,
    required this.openLabel,
  });

  String prompt;
  String style;
  int accentArgb;
  List<int> swatchArgb;
  String generatingTitle;
  String readyTitle;
  String failedTitle;
  String staleTitle;
  String openLabel;
}

@HostApi()
abstract class PrismLiveActivityHostApi {
  /// Starts the AI generation Live Activity and keeps the app running in the background until it ends. Null when
  /// Live Activities are off or not supported.
  String? startAiGeneration(AiActivityRequest request);

  /// Shows the finished wallpaper, then lets the system dismiss the activity a few minutes later.
  @async
  void finishAiGeneration(String activityId, String imageUrl);

  void failAiGeneration(String activityId, String detail);

  /// Removes the activity at once, for a generation that stopped without a result to show.
  void cancelAiGeneration(String activityId);
}
