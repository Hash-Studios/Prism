import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart';

final RegExp _googlePhotoSize = RegExp(r'=s\d+(-c)?$');

/// [photoUrl], or the placeholder when it is blank. A profile with no photo stores the placeholder.
String photoOrPlaceholder(String? photoUrl) {
  final String url = (photoUrl ?? '').trim();
  return url.isEmpty ? defaultProfilePhotoUrl : url;
}

/// [photoUrl] from Google at 400 px, the size of an uploaded profile photo, or null when Google has no photo.
/// Android and iOS ask Google for other sizes.
String? sizedGooglePhoto(String? photoUrl) {
  final String url = (photoUrl ?? '').trim();
  return url.isEmpty ? null : url.replaceFirst(_googlePhotoSize, '=s400-c');
}

/// Whether [photoUrl] is a photo that the user uploaded in Prism: not the placeholder and not a Google account photo.
bool isCustomProfilePhoto(String photoUrl) {
  final String url = photoUrl.trim();
  if (url.isEmpty || url == defaultProfilePhotoUrl) {
    return false;
  }
  return !(Uri.tryParse(url)?.host ?? '').endsWith('googleusercontent.com');
}

/// Whether [a] and [b] are the same photo. Android and iOS ask Google for different sizes of one photo.
bool isSamePhoto(String? a, String? b) =>
    (a ?? '').trim().replaceFirst(_googlePhotoSize, '') == (b ?? '').trim().replaceFirst(_googlePhotoSize, '');

/// The profile fields that a Google sign-in changes. A name or photo that the user set in Prism stays.
///
/// The name follows Google while it still equals [lastGoogleName], the Google name of the last sign-in. The photo
/// follows Google while it is not a custom photo. [googlePhotoUrl] is the placeholder when Google has no photo.
Map<String, String> googleProfileUpdates(
  PrismUsersV2 profile, {
  required String? lastGoogleName,
  required String googleName,
  required String googlePhotoUrl,
}) {
  return <String, String>{
    if (profile.name == lastGoogleName && profile.name != googleName) 'name': googleName,
    if (!isCustomProfilePhoto(profile.profilePhoto) && !isSamePhoto(profile.profilePhoto, googlePhotoUrl))
      'profilePhoto': googlePhotoUrl,
  };
}
