import 'package:Prism/features/profile_setups/domain/entities/profile_setup_entity.dart';

class ProfileSetupsPage {
  const ProfileSetupsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ProfileSetupEntity> items;
  final bool hasMore;
  final String? nextCursor;
}
