import 'package:Prism/auth/google_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'userOldModel.g.dart';

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
    debugPrint("Default constructor !!!!");
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
    debugPrint("With Save constructor !!!!");
    FirebaseFirestore.instance.collection(USER_NEW_COLLECTION).doc(id).update({
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
    debugPrint("initial constructor !!!!");
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
    debugPrint("Without save constructor !!!!");
    FirebaseFirestore.instance.collection(USER_NEW_COLLECTION).doc(id).update({
      'bio': bio,
      'username': username,
      'following': following,
      'lastLogin': DateTime.now(),
      'links': links,
      'profilePhoto': profilePhoto,
    });
  }

  factory PrismUsers.fromDocumentSnapshot(DocumentSnapshot doc, User user) =>
      PrismUsers.withoutSave(
        bio: (doc.data()!["bio"] ?? "").toString(),
        createdAt: doc.data()!["createdAt"].toString(),
        email: doc.data()!["email"].toString(),
        username: (doc.data()!["username"] ?? user.displayName).toString(),
        followers: doc.data()!["followers"] as List ?? [],
        following: doc.data()!["following"] as List ?? [],
        id: doc.data()!["id"].toString(),
        lastLogin: ((doc.data()!["lastLogin"] as Timestamp?) ?? Timestamp.now())
            .toDate(),
        links: doc.data()!["links"] as Map ?? {},
        premium: doc.data()!["premium"] as bool,
        loggedIn: true,
        profilePhoto: (doc.data()!["profilePhoto"] ?? user.photoURL).toString(),
      );

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
