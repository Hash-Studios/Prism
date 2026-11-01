import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_directory/biz/followed_by_cubit.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Followed by Ana and 2 others you follow", with up to 3 avatars. Shows nothing for signed-out viewers, the viewer's
/// own profile, or when no one the viewer follows follows this creator.
class FollowedByLine extends StatefulWidget {
  const FollowedByLine({super.key, required this.creatorUid});

  final String creatorUid;

  @override
  State<FollowedByLine> createState() => _FollowedByLineState();
}

class _FollowedByLineState extends State<FollowedByLine> {
  late final FollowedByCubit _cubit = getIt<FollowedByCubit>();
  bool _tracked = false;
  String _viewer = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FollowedByLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.creatorUid != widget.creatorUid || _viewer != app_state.prismUser.id) _load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _load() {
    _tracked = false;
    _viewer = app_state.prismUser.id;
    _cubit.load(widget.creatorUid);
  }

  @override
  Widget build(BuildContext context) {
    if (!app_state.prismUser.loggedIn || _viewer != app_state.prismUser.id) return const SizedBox.shrink();
    return BlocBuilder<FollowedByCubit, FollowedBy?>(
      bloc: _cubit,
      builder: (context, data) {
        if (data == null) return const SizedBox.shrink();
        if (data.count == 0 || data.people.isEmpty) return const SizedBox.shrink();
        if (!_tracked) {
          _tracked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            analytics.track(FollowedByShownEvent(count: data.count));
          });
        }
        final List<String> names = data.people.map((p) => p.name).toList(growable: false);
        final String text;
        if (data.count >= 3 && names.length >= 2) {
          text = context.l10n.creatorsFollowedByMany(names[0], names[1], data.count - 2);
        } else if (data.count >= 2 && names.length >= 2) {
          text = context.l10n.creatorsFollowedByTwo(names[0], names[1]);
        } else {
          text = context.l10n.creatorsFollowedByOne(names[0]);
        }
        final List<FollowedByPerson> shown = data.people.take(3).toList(growable: false);
        final ColorScheme cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: PrismSpace.sm),
          child: Semantics(
            label: text,
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 24 + (shown.length - 1) * 16,
                  height: 24,
                  child: ExcludeSemantics(
                    child: Stack(
                      children: <Widget>[
                        for (int i = 0; i < shown.length; i++)
                          Positioned(
                            left: i * 16,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: cs.surface, width: 2),
                              ),
                              child: PrismAvatar(url: shown[i].photoUrl, name: shown[i].name, size: 24),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: PrismSpace.xs),
                Expanded(child: Text(text, style: PrismTextStyles.caption(context))),
              ],
            ),
          ),
        );
      },
    );
  }
}
