import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart';

/// A signed-in user with the profile fields the completeness checks read.
/// Defaults to the placeholder photo and empty username, bio and links.
PrismUsersV2 profileUser({
  String id = 'u1',
  bool loggedIn = true,
  bool premium = false,
  String profilePhoto = defaultProfilePhotoUrl,
  String username = '',
  String bio = '',
  Map<String, String> links = const <String, String>{},
}) {
  final String now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    username: username,
    email: 'user@example.com',
    id: id,
    createdAt: now,
    premium: premium,
    lastLoginAt: now,
    links: links,
    followers: const <String>[],
    following: const <String>[],
    profilePhoto: profilePhoto,
    bio: bio,
    loggedIn: loggedIn,
    badges: <Badge>[],
    subPrisms: const <String>[],
    coins: 0,
    transactions: <PrismTransaction>[],
    name: '',
    coverPhoto: '',
  );
}
