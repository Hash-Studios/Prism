import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

Map<String, dynamic> _legacyDocumentData(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

class PrismUsers {
  String username;
  String email;
  String id;
  String createdAt;
  bool premium;
  DateTime lastLogin;
  Map links;
  List followers;
  List following;
  String profilePhoto;
  String bio;
  bool loggedIn;

  PrismUsers({
    required this.username,
    required this.email,
    required this.id,
    required this.createdAt,
    required this.premium,
    required this.lastLogin,
    required this.links,
    required this.followers,
    required this.following,
    required this.profilePhoto,
    required this.bio,
    required this.loggedIn,
  }) {
    logger.d("Default constructor !!!!");
  }

  PrismUsers.withSave({
    required this.username,
    required this.email,
    required this.id,
    required this.createdAt,
    required this.premium,
    required this.lastLogin,
    required this.links,
    required this.followers,
    required this.following,
    required this.profilePhoto,
    required this.bio,
    required this.loggedIn,
  }) {
    logger.d("With Save constructor !!!!");
    firestoreClient.updateDoc(USER_NEW_COLLECTION, id, {
      'bio': bio,
      'username': username,
      'email': email,
      'id': id,
      'createdAt': createdAt,
      'premium': premium,
      'lastLogin': lastLogin,
      'links': links,
      'followers': followers,
      'following': following,
      'profilePhoto': profilePhoto,
    }, sourceTag: 'user_old.with_save');
  }
  PrismUsers.initial({
    this.bio = "",
    this.email = "",
    this.username = "",
    this.id = "",
    required this.createdAt,
    this.premium = false,
    required this.lastLogin,
    required this.links,
    required this.followers,
    required this.following,
    this.profilePhoto = "",
    this.loggedIn = false,
  }) {
    logger.d("initial constructor !!!!");
  }

  PrismUsers.withoutSave({
    required this.username,
    required this.email,
    required this.id,
    required this.createdAt,
    required this.premium,
    required this.lastLogin,
    required this.links,
    required this.followers,
    required this.following,
    required this.profilePhoto,
    required this.bio,
    required this.loggedIn,
  }) {
    logger.d("Without save constructor !!!!");
    firestoreClient.updateDoc(USER_NEW_COLLECTION, id, {
      'bio': bio,
      'username': username,
      'following': following,
      'lastLogin': DateTime.now(),
      'links': links,
      'profilePhoto': profilePhoto,
    }, sourceTag: 'user_old.without_save');
  }

  factory PrismUsers.fromMapWithUser(Map<String, dynamic> raw, User user) {
    final data = _legacyDocumentData(raw);
    DateTime parsedLastLogin;
    try {
      final dynamic lastLoginValue = data["lastLogin"];
      parsedLastLogin = lastLoginValue?.toDate() as DateTime? ?? DateTime.now();
    } catch (_) {
      parsedLastLogin = DateTime.now();
    }
    return PrismUsers.withoutSave(
      bio: (data["bio"] ?? "").toString(),
      createdAt: data["createdAt"].toString(),
      email: data["email"].toString(),
      username: (data["username"] ?? user.displayName).toString(),
      followers: data["followers"] as List? ?? <dynamic>[],
      following: data["following"] as List? ?? <dynamic>[],
      id: data["id"].toString(),
      lastLogin: parsedLastLogin,
      links: data["links"] as Map? ?? <dynamic, dynamic>{},
      premium: data["premium"] as bool? ?? false,
      loggedIn: true,
      profilePhoto: (data["profilePhoto"] ?? user.photoURL).toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    "bio": bio,
    "createdAt": createdAt,
    "email": email,
    "username": username,
    "links": links,
    "premium": premium,
    "profilePhoto": profilePhoto,
  };
}
