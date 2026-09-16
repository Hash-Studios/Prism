import 'package:Prism/features/public_profile/views/widgets/user_relation_list_body.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class FollowingListScreen extends StatelessWidget {
  const FollowingListScreen({super.key, required this.following});

  /// Full list of email addresses that the current user follows (all pages).
  final List<String> following;

  @override
  Widget build(BuildContext context) {
    return UserRelationListBody(kind: UserRelationKind.following, emails: following);
  }
}
