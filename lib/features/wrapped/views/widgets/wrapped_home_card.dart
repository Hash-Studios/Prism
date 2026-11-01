import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/wrapped/biz/bloc/wrapped_bloc.j.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/wrapped_config.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

/// The Wrapped to promote on Home: only inside the Remote Config window and only for [uid]'s own loaded Wrapped.
WrappedYear? wrappedForHome(WrappedState state, String uid, DateTime now) => switch (state) {
  WrappedReady(uid: final owner, :final year) when owner == uid && uid.isNotEmpty && WrappedConfig.isOpen(now) => year,
  _ => null,
};

class WrappedHomeCard extends StatelessWidget {
  const WrappedHomeCard({required this.year, required this.memCacheHeight, super.key});

  final WrappedYear year;
  final int memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final String title = context.l10n.wrappedHomeTitle('${year.year}');
    return FeedHeroCard(
      image: PrismImageTile(url: year.cards.first.heroUrl, memCacheHeight: memCacheHeight),
      semanticLabel: title,
      title: title,
      subtitle: context.l10n.wrappedHomeSubtitle,
      onTap: () => context.router.push(PrismWrappedRoute(source: WrappedSourceValue.home)),
    );
  }
}
