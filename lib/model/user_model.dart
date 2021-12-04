import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:prism/model/badge_model.dart';
import 'package:prism/model/transaction_model.dart';
import 'package:prism/services/logger.dart';

part 'user_model.g.dart';

@JsonSerializable(
  explicitToJson: true,
)
class PrismUsersV2 {
  String username;
  String email;
  String id;
  String createdAt;
  bool premium;
  String lastLoginAt;
  Map links;
  List followers;
  List following;
  String profilePhoto;
  String bio;
  bool loggedIn;
  List<Badge> badges;
  List subPrisms;
  int coins;
  List<PrismTransaction> transactions;
  String name;
  String? coverPhoto;

  PrismUsersV2({
    required this.username,
    required this.email,
    required this.id,
    required this.createdAt,
    required this.premium,
    required this.lastLoginAt,
    required this.links,
    required this.followers,
    required this.following,
    required this.profilePhoto,
    required this.bio,
    required this.loggedIn,
    required this.badges,
    required this.subPrisms,
    required this.coins,
    required this.transactions,
    required this.name,
    this.coverPhoto,
  }) {
    logger.d("Default constructor !!!!");
  }

  factory PrismUsersV2.fromJson(Map<String, dynamic> json) =>
      _$PrismUsersV2FromJson(json);
  factory PrismUsersV2.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc, User user) {
    final Map<String, dynamic> mapData = doc.data()!;
    return PrismUsersV2(
      name: (mapData["name"] ?? user.displayName).toString(),
      username: (mapData["username"] ?? user.displayName)
          .toString()
          .replaceAll(RegExp(r"(?: |[^\w\s])+"), ""),
      email: (mapData["email"] ?? user.email).toString(),
      id: mapData["id"].toString(),
      createdAt: mapData["createdAt"].toString(),
      premium: mapData["premium"] as bool,
      lastLoginAt: mapData["lastLoginAt"]?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      links: mapData["links"] as Map<String, dynamic> ?? {},
      followers: mapData["followers"] as List ?? [],
      following: mapData["following"] as List ?? [],
      profilePhoto: (mapData["profilePhoto"] ?? user.photoURL).toString(),
      bio: (mapData["bio"] ?? "").toString(),
      loggedIn: true,
      badges: (mapData['badges'] as List<dynamic> ?? [])
          .map((e) => Badge.fromJson(e as Map<String, dynamic>))
          .toList(),
      subPrisms: mapData['subPrisms'] as List<dynamic> ?? [],
      coins: mapData['coins'] as int ?? 0,
      transactions: (mapData['transactions'] as List<dynamic> ?? [])
          .map((e) => PrismTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      coverPhoto: mapData["coverPhoto"]?.toString(),
    );
  }

  factory PrismUsersV2.fromDocumentSnapshotWithoutUser(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> mapData = doc.data()!;
    return PrismUsersV2(
      name: (mapData["name"] ?? "").toString(),
      username: (mapData["username"] ?? "")
          .toString()
          .replaceAll(RegExp(r"(?: |[^\w\s])+"), ""),
      email: (mapData["email"] ?? "").toString(),
      id: mapData["id"].toString(),
      createdAt: DateTime.parse(mapData["createdAt"] as String)
          .toUtc()
          .toIso8601String(),
      premium: mapData["premium"] as bool,
      lastLoginAt: mapData["lastLoginAt"]?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      links: mapData["links"] as Map<String, dynamic> ?? {},
      followers: mapData["followers"] as List ?? [],
      following: mapData["following"] as List ?? [],
      profilePhoto: (mapData["profilePhoto"] ?? "").toString(),
      bio: (mapData["bio"] ?? "").toString(),
      loggedIn: true,
      badges: (mapData['badges'] as List<dynamic> ?? [])
          .map((e) => Badge.fromJson(e as Map<String, dynamic>))
          .toList(),
      subPrisms: mapData['subPrisms'] as List<dynamic> ?? [],
      coins: mapData['coins'] as int ?? 0,
      transactions: (mapData['transactions'] as List<dynamic> ?? [])
          .map((e) => PrismTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      coverPhoto: mapData["coverPhoto"]?.toString(),
    );
  }
  Map<String, dynamic> toJson() => _$PrismUsersV2ToJson(this);
}
