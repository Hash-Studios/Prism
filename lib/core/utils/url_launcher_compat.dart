import 'package:url_launcher/url_launcher.dart' as launcher;

typedef LaunchMode = launcher.LaunchMode;

Future<bool> launch(String url) {
  return launcher.launchUrl(Uri.parse(url));
}

Future<bool> launchUrl(
  Uri url, {
  LaunchMode mode = LaunchMode.platformDefault,
}) {
  return launcher.launchUrl(url, mode: mode);
}
