import 'package:Prism/features/session/domain/entities/badge_entity.dart';
import 'package:Prism/features/session/domain/entities/transaction_entity.dart';

class SessionEntity {
  const SessionEntity({
    required this.userId,
    required this.email,
    required this.name,
    required this.username,
    required this.profilePhoto,
    required this.coverPhoto,
    required this.bio,
    required this.loggedIn,
    required this.premium,
    required this.subscriptionTier,
    required this.coins,
    required this.links,
    required this.followers,
    required this.following,
    required this.badges,
    required this.transactions,
    required this.subPrisms,
    required this.uploadsWeekStart,
    required this.uploadsThisWeek,
  });

  final String userId;
  final String email;
  final String name;
  final String username;
  final String profilePhoto;
  final String coverPhoto;
  final String bio;
  final bool loggedIn;
  final bool premium;
  final String subscriptionTier;
  final int coins;
  final Map<String, String> links;
  final List<String> followers;
  final List<String> following;
  final List<BadgeEntity> badges;
  final List<TransactionEntity> transactions;
  final List<String> subPrisms;
  final String uploadsWeekStart;
  final int uploadsThisWeek;

  static const SessionEntity guest = SessionEntity(
    userId: '',
    email: '',
    name: '',
    username: '',
    profilePhoto: '',
    coverPhoto: '',
    bio: '',
    loggedIn: false,
    premium: false,
    subscriptionTier: 'free',
    coins: 0,
    links: <String, String>{},
    followers: <String>[],
    following: <String>[],
    badges: <BadgeEntity>[],
    transactions: <TransactionEntity>[],
    subPrisms: <String>[],
    uploadsWeekStart: '',
    uploadsThisWeek: 0,
  );
}
