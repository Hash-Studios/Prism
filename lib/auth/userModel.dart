import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'userModel.g.dart';

Map<String, dynamic> _mapData(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

@HiveType(typeId: 15)
@JsonSerializable(
  explicitToJson: true,
)
class PrismUsersV2 {
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
  String lastLoginAt;
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
  @HiveField(12)
  List<Badge> badges;
  @HiveField(13)
  List subPrisms;
  @HiveField(14)
  int coins;
  @HiveField(15)
  List<PrismTransaction> transactions;
  @HiveField(16)
  String name;
  @HiveField(17)
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

  factory PrismUsersV2.fromJson(Map<String, dynamic> json) => _$PrismUsersV2FromJson(json);
  factory PrismUsersV2.fromMapWithUser(Map<String, dynamic> raw, User user) {
    final data = _mapData(raw);
    return PrismUsersV2(
        name: (data["name"] ?? user.displayName).toString(),
        username: (data["username"] ?? user.displayName).toString().replaceAll(RegExp(r"(?: |[^\w\s])+"), ""),
        email: (data["email"] ?? user.email).toString(),
        id: data["id"].toString(),
        createdAt: data["createdAt"].toString(),
        premium: data["premium"] as bool? ?? false,
        lastLoginAt: data["lastLoginAt"]?.toString() ?? DateTime.now().toUtc().toIso8601String(),
        links: data["links"] as Map<String, dynamic>? ?? <String, dynamic>{},
        followers: data["followers"] as List? ?? <dynamic>[],
        following: data["following"] as List? ?? <dynamic>[],
        profilePhoto: (data["profilePhoto"] ?? user.photoURL).toString(),
        bio: (data["bio"] ?? "").toString(),
        loggedIn: true,
        badges: (data['badges'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Badge.fromJson(e as Map<String, dynamic>))
            .toList(),
        subPrisms: data['subPrisms'] as List<dynamic>? ?? <dynamic>[],
        coins: data['coins'] as int? ?? 0,
        transactions: (data['transactions'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => PrismTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        coverPhoto: data["coverPhoto"]?.toString());
  }

  factory PrismUsersV2.fromMapWithoutUser(Map<String, dynamic> raw) {
    final data = _mapData(raw);
    return PrismUsersV2(
        name: (data["name"] ?? "").toString(),
        username: (data["username"] ?? "").toString().replaceAll(RegExp(r"(?: |[^\w\s])+"), ""),
        email: (data["email"] ?? "").toString(),
        id: data["id"].toString(),
        createdAt: DateTime.parse((data["createdAt"] ?? DateTime.now().toUtc().toIso8601String()).toString())
            .toUtc()
            .toIso8601String(),
        premium: data["premium"] as bool? ?? false,
        lastLoginAt: data["lastLoginAt"]?.toString() ?? DateTime.now().toUtc().toIso8601String(),
        links: data["links"] as Map<String, dynamic>? ?? <String, dynamic>{},
        followers: data["followers"] as List? ?? <dynamic>[],
        following: data["following"] as List? ?? <dynamic>[],
        profilePhoto: (data["profilePhoto"] ?? "").toString(),
        bio: (data["bio"] ?? "").toString(),
        loggedIn: true,
        badges: (data['badges'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Badge.fromJson(e as Map<String, dynamic>))
            .toList(),
        subPrisms: data['subPrisms'] as List<dynamic>? ?? <dynamic>[],
        coins: data['coins'] as int? ?? 0,
        transactions: (data['transactions'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => PrismTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        coverPhoto: data["coverPhoto"]?.toString());
  }
  Map<String, dynamic> toJson() => _$PrismUsersV2ToJson(this);
}
