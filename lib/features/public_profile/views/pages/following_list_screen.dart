import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/views/widgets/user_relation_list_body.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class FollowingListScreen extends StatelessWidget {
  const FollowingListScreen({super.key, required this.userId});

  /// Uid of the profile whose following edges are loaded when the screen opens.
  final String userId;

  @override
  Widget build(BuildContext context) {
    return UserRelationListBody(kind: UserRelationKind.following, profileUid: userId);
  }
}
