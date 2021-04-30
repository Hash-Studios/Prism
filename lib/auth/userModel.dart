import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'userModel.g.dart';

@HiveType(typeId: 1)
class PrismUsers {
  @HiveField(0)
  String username;
  @HiveField(1)
  String email;
  @HiveField(2)
  String id;
  @HiveField(3)
  String createdAt;
  @HiveField(4)
  bool premium;
  @HiveField(5)
  DateTime lastLogin;
  @HiveField(6)
  Map links;
  @HiveField(7)
  List followers;
  @HiveField(8)
  List following;
  @HiveField(9)
  String profilePhoto;
  @HiveField(10)
  String bio;
  @HiveField(11)
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
    print("Default constructor !!!!");
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
    print("With Save constructor !!!!");
    Firestore.instance.collection('users').document(id).updateData({
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
    });
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
    print("initial constructor !!!!");
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
    print("Without save constructor !!!!");
    Firestore.instance.collection('users').document(id).updateData({
      'bio': bio,
      'username': username,
      'following': following,
      'lastLogin': DateTime.now(),
      'links': links,
      'profilePhoto': profilePhoto,
    });
  }

  factory PrismUsers.fromDocumentSnapshot(
          DocumentSnapshot doc, FirebaseUser user) =>
      PrismUsers.withoutSave(
        bio: (doc["bio"] ?? "").toString(),
        createdAt: doc["createdAt"].toString(),
        email: doc["email"].toString(),
        username: (doc["username"] ?? user.displayName).toString(),
        followers: doc["followers"] as List ?? [],
        following: doc["following"] as List ?? [],
        id: doc["id"].toString(),
        lastLogin:
            ((doc["lastLogin"] as Timestamp?) ?? Timestamp.now()).toDate(),
        links: doc["links"] as Map ?? {},
        premium: doc["premium"] as bool,
        loggedIn: true,
        profilePhoto: (doc["profilePhoto"] ?? user.photoUrl).toString(),
      );
}
