import 'package:Prism/features/profile_walls/domain/entities/profile_wall_entity.dart';

class ProfileWallsPage {
  const ProfileWallsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ProfileWallEntity> items;
  final bool hasMore;
  final String? nextCursor;
}
