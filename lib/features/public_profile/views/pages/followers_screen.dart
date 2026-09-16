import 'package:Prism/features/public_profile/views/widgets/user_relation_list_body.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class FollowersScreen extends StatelessWidget {
  const FollowersScreen({super.key, required this.followers});

  /// Full list of follower email addresses (all pages). Passed from profile screen.
  final List<String> followers;

  @override
  Widget build(BuildContext context) {
    return UserRelationListBody(kind: UserRelationKind.followers, emails: followers);
  }
}
