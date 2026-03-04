import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:Prism/logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_io/hive_io.dart';
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

List<String> _toStringList(Object? value) {
  if (value is List) {
    return value.whereType<Object?>().map((Object? e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }
  return <String>[];
}

Map<String, String> _toStringMap(Object? value) {
  if (value is Map) {
    final Map<String, String> out = <String, String>{};
    for (final MapEntry<Object?, Object?> e in value.entries) {
      final String key = e.key?.toString() ?? '';
      if (key.isEmpty || e.value == null) continue;
      out[key] = e.value.toString();
    }
    return out;
  }
  return <String, String>{};
}

List<Badge> _toBadgeList(Object? value) {
  if (value is! List) return <Badge>[];
  return value
      .whereType<Map>()
      .map((Map e) => e.map((k, v) => MapEntry(k.toString(), v)))
      .map(Badge.fromJson)
      .toList(growable: false);
}

List<PrismTransaction> _toTransactionList(Object? value) {
  if (value is! List) return <PrismTransaction>[];
  return value
      .whereType<Map>()
      .map((Map e) => e.map((k, v) => MapEntry(k.toString(), v)))
      .map(PrismTransaction.fromJson)
      .toList(growable: false);
}

String _resolveTierValue({required bool premium, required Object? raw}) {
  final SubscriptionTier parsed = SubscriptionTier.fromValue(raw?.toString());
  if (parsed != SubscriptionTier.free) {
    return parsed.value;
  }
  return premium ? SubscriptionTier.pro.value : SubscriptionTier.free.value;
}

@HiveType(typeId: 15)
@JsonSerializable(explicitToJson: true)
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
  Map<String, String> links;
  @HiveField(7)
  List<String> followers;
  @HiveField(8)
  List<String> following;
  @HiveField(9)
  String profilePhoto;
  @HiveField(10)
  String bio;
  @HiveField(11)
  bool loggedIn;
  @HiveField(12)
  List<Badge> badges;
  @HiveField(13)
  List<String> subPrisms;
  @HiveField(14)
  int coins;
  @HiveField(15)
  List<PrismTransaction> transactions;
  @HiveField(16)
  String name;
  @HiveField(17)
  String? coverPhoto;
  @HiveField(18)
  String subscriptionTier;
  @HiveField(19)
  String uploadsWeekStart;
  @HiveField(20)
  int uploadsThisWeek;

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
    this.subscriptionTier = 'free',
    this.uploadsWeekStart = '',
    this.uploadsThisWeek = 0,
  }) {
    logger.d("Default constructor !!!!");
  }

  factory PrismUsersV2.fromJson(Map<String, dynamic> json) => _$PrismUsersV2FromJson(json);
  factory PrismUsersV2.fromMapWithUser(Map<String, dynamic> raw, User user) {
    final data = _mapData(raw);
    final bool rawPremium = data["premium"] as bool? ?? false;
    final String tierValue = _resolveTierValue(premium: rawPremium, raw: data['subscriptionTier']);
    final bool premium = SubscriptionTier.fromValue(tierValue).isPaid || rawPremium;
    return PrismUsersV2(
      name: (data["name"] ?? user.displayName).toString(),
      username: (data["username"] ?? user.displayName).toString().replaceAll(RegExp(r"(?: |[^\w\s])+"), ""),
      email: (data["email"] ?? user.email).toString(),
      id: data["id"].toString(),
      createdAt: data["createdAt"].toString(),
      premium: premium,
      lastLoginAt: data["lastLoginAt"]?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      links: _toStringMap(data["links"]),
      followers: _toStringList(data["followers"]),
      following: _toStringList(data["following"]),
      profilePhoto: (data["profilePhoto"] ?? user.photoURL).toString(),
      bio: (data["bio"] ?? "").toString(),
      loggedIn: true,
      badges: _toBadgeList(data['badges']),
      subPrisms: _toStringList(data['subPrisms']),
      coins: data['coins'] as int? ?? 0,
      transactions: _toTransactionList(data['transactions']),
      coverPhoto: data["coverPhoto"]?.toString(),
      subscriptionTier: tierValue,
      uploadsWeekStart: data['uploadsWeekStart']?.toString() ?? '',
      uploadsThisWeek: data['uploadsThisWeek'] as int? ?? 0,
    );
  }

  factory PrismUsersV2.fromMapWithoutUser(Map<String, dynamic> raw) {
    final data = _mapData(raw);
    final bool rawPremium = data["premium"] as bool? ?? false;
    final String tierValue = _resolveTierValue(premium: rawPremium, raw: data['subscriptionTier']);
    final bool premium = SubscriptionTier.fromValue(tierValue).isPaid || rawPremium;
    return PrismUsersV2(
      name: (data["name"] ?? "").toString(),
      username: (data["username"] ?? "").toString().replaceAll(RegExp(r"(?: |[^\w\s])+"), ""),
      email: (data["email"] ?? "").toString(),
      id: data["id"].toString(),
      createdAt: DateTime.parse(
        (data["createdAt"] ?? DateTime.now().toUtc().toIso8601String()).toString(),
      ).toUtc().toIso8601String(),
      premium: premium,
      lastLoginAt: data["lastLoginAt"]?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      links: _toStringMap(data["links"]),
      followers: _toStringList(data["followers"]),
      following: _toStringList(data["following"]),
      profilePhoto: (data["profilePhoto"] ?? "").toString(),
      bio: (data["bio"] ?? "").toString(),
      loggedIn: true,
      badges: _toBadgeList(data['badges']),
      subPrisms: _toStringList(data['subPrisms']),
      coins: data['coins'] as int? ?? 0,
      transactions: _toTransactionList(data['transactions']),
      coverPhoto: data["coverPhoto"]?.toString(),
      subscriptionTier: tierValue,
      uploadsWeekStart: data['uploadsWeekStart']?.toString() ?? '',
      uploadsThisWeek: data['uploadsThisWeek'] as int? ?? 0,
    );
  }
  Map<String, dynamic> toJson() => _$PrismUsersV2ToJson(this);
}
