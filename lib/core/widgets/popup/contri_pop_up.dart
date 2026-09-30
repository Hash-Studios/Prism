import 'package:Prism/core/widgets/popup/popup_link.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';

/// Opens a sheet with the GitHub profile of [username].
void showContributorDetails(BuildContext context, String username) {
  showPrismSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ContributorSheet(username: username),
  );
}

class _ContributorSheet extends StatefulWidget {
  const _ContributorSheet({required this.username});

  final String username;

  @override
  State<_ContributorSheet> createState() => _ContributorSheetState();
}

class _ContributorSheetState extends State<_ContributorSheet> {
  late Future<User> _user = GitHub().users.getUser(widget.username);

  void _retry() => setState(() => _user = GitHub().users.getUser(widget.username));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: _user,
      builder: (context, snapshot) {
        final User? user = snapshot.data;
        if (snapshot.hasError || (snapshot.connectionState == ConnectionState.done && user == null)) {
          return PrismSheetBody(
            child: GlintState(
              kind: GlintStateKind.error,
              title: 'Could not load this profile',
              body: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: _retry,
            ),
          );
        }
        if (user == null) {
          return const PrismSheetBody(child: _ProfileSkeleton());
        }
        return _ContributorBody(user: user);
      },
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const PrismSkeleton(
      child: Column(
        children: <Widget>[
          PrismBone.circle(size: 72),
          SizedBox(height: PrismSpace.sm),
          PrismBone(width: 160, height: 22),
          SizedBox(height: PrismSpace.xs),
          PrismBone(width: 110, height: 12),
          SizedBox(height: PrismSpace.md),
          PrismBone(width: 240, height: 12),
          SizedBox(height: PrismSpace.xxl),
        ],
      ),
    );
  }
}

class _ContributorBody extends StatelessWidget {
  const _ContributorBody({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final TextStyle body = PrismTextStyles.body(context);
    final String? name = user.name?.trim();
    final String displayName = name == null || name.isEmpty ? (user.login ?? '') : name;
    final String? location = user.location?.trim();
    final String? bio = user.bio?.trim();
    final String? blog = user.blog?.trim();
    final String? htmlUrl = user.htmlUrl;
    final String? twitter = user.twitterUsername;
    return PrismSheetBody(
      centered: true,
      child: Column(
        children: <Widget>[
          PrismAvatar(url: user.avatarUrl, name: displayName, size: 72),
          const SizedBox(height: PrismSpace.sm),
          Semantics(
            header: true,
            child: Text(
              displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: PrismTextStyles.sheetHeadline(context),
            ),
          ),
          if (user.login != null) ...<Widget>[
            const SizedBox(height: PrismSpace.xxs),
            Text('@${user.login}', textAlign: TextAlign.center, style: body),
          ],
          if (location != null && location.isNotEmpty) ...<Widget>[
            const SizedBox(height: PrismSpace.xxs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.place_rounded, size: 16, color: body.color),
                const SizedBox(width: PrismSpace.xxs),
                Flexible(
                  child: Text(location, overflow: TextOverflow.ellipsis, style: body),
                ),
              ],
            ),
          ],
          if (bio != null && bio.isNotEmpty) ...<Widget>[
            const SizedBox(height: PrismSpace.md),
            Text(
              bio,
              textAlign: TextAlign.center,
              style: body.copyWith(color: Theme.of(context).colorScheme.onSurface, height: 1.4),
            ),
          ],
          const SizedBox(height: PrismSpace.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              if (blog != null && blog.isNotEmpty)
                PopupLinkChip(
                  icon: JamIcons.link,
                  label: 'Website',
                  link: blog.startsWith('http') ? blog : 'https://$blog',
                ),
              if (htmlUrl != null) PopupLinkChip(icon: JamIcons.github, label: 'GitHub', link: htmlUrl),
              if (twitter != null && twitter.isNotEmpty)
                PopupLinkChip(icon: JamIcons.twitter, label: 'Twitter', link: 'https://www.twitter.com/$twitter'),
            ],
          ),
        ],
      ),
    );
  }
}
