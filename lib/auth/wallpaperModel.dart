// import 'package:Prism/auth/badgeModel.dart';
// import 'package:Prism/auth/transactionModel.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:json_annotation/json_annotation.dart';

// part 'wallpaperModel.g.dart';

// enum WallpaperProvider { Prism, Wallhaven, Pexels }

// extension WallExtension on WallpaperProvider {
//   String get name {
//     return this.toString().split('.').last;
//   }
// }

// @HiveType(typeId: 16)
// @JsonSerializable(
//   explicitToJson: true,
// )
// class WallpaperV2 {
//   @HiveField(0)
//   String username;
//   @HiveField(1)
//   List<String> collections;
//   @HiveField(2)
//   String id;
//   @HiveField(3)
//   DateTime createdAt;
//   @HiveField(4)
//   String description;
//   @HiveField(5)
//   String resolution;
//   @HiveField(6)
//   bool review;
//   @HiveField(7)
//   String size;
//   @HiveField(8)
//   String profilePhoto;
//   @HiveField(9)
//   String wallpaper_provider;
//   @HiveField(10)
//   String wallpaper_url;
//   @HiveField(11)
//   String wallpaper_thumb;
//   @HiveField(12)
//   List subPrisms;
//   @HiveField(13)
//   bool free;
//   @HiveField(14)
//   int coins;
//   @HiveField(15)
//   String link;

//   WallpaperV2({
//     required this.username,
//     required this.email,
//     required this.id,
//     required this.createdAt,
//     required this.premium,
//     required this.lastLoginAt,
//     required this.links,
//     required this.followers,
//     required this.following,
//     required this.profilePhoto,
//     required this.bio,
//     required this.loggedIn,
//     required this.badges,
//     required this.subPrisms,
//     required this.coins,
//     required this.transactions,
//     required this.name,
//     this.coverPhoto,
//   }) {
//     debugPrint("Default constructor !!!!");
//   }

//   factory PrismUsersV2.fromJson(Map<String, dynamic> json) =>
//       _$PrismUsersV2FromJson(json);
//   factory PrismUsersV2.fromDocumentSnapshot(DocumentSnapshot doc, User user) =>
//       PrismUsersV2(
//         name: (doc.data()!["name"] ?? user.displayName).toString(),
//         username: (doc.data()!["username"] ?? user.displayName)
//             .toString()
//             .replaceAll(RegExp(r"(?: |[^\w\s])+"), ""),
//         email: (doc.data()!["email"] ?? user.email).toString(),
//         id: doc.data()!["id"].toString(),
//         createdAt: doc.data()!["createdAt"].toString(),
//         premium: doc.data()!["premium"] as bool,
//         lastLoginAt: doc.data()!["lastLoginAt"]?.toString() ??
//             DateTime.now().toUtc().toIso8601String(),
//         links: doc.data()!["links"] as Map<String, dynamic> ?? {},
//         followers: doc.data()!["followers"] as List ?? [],
//         following: doc.data()!["following"] as List ?? [],
//         profilePhoto: (doc.data()!["profilePhoto"] ?? user.photoURL).toString(),
//         bio: (doc.data()!["bio"] ?? "").toString(),
//         loggedIn: true,
//         badges: (doc.data()!['badges'] as List<dynamic> ?? [])
//             .map((e) => Badge.fromJson(e as Map<String, dynamic>))
//             .toList(),
//         subPrisms: doc.data()!['subPrisms'] as List<dynamic> ?? [],
//         coins: doc.data()!['coins'] as int ?? 0,
//         transactions: (doc.data()!['transactions'] as List<dynamic> ?? [])
//             .map((e) => PrismTransaction.fromJson(e as Map<String, dynamic>))
//             .toList(),
//         coverPhoto: doc.data()!["coverPhoto"]?.toString(),
//       );
//   Map<String, dynamic> toJson() => _$PrismUsersV2ToJson(this);
// }
