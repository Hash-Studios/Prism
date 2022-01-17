import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:prism/controllers/hide_controller.dart';
import 'package:prism/controllers/settings_controller.dart';
import 'package:prism/controllers/wallhaven_controller.dart';
import 'package:prism/model/settings/wall_display_mode.dart';
import 'package:prism/model/wallhaven/wallhaven_search_state.dart';
import 'package:prism/model/wallhaven/wallhaven_wall_model.dart';
import 'package:prism/services/logger.dart';
import 'package:prism/widgets/wallhaven_immersive_wall_card.dart';
import 'package:prism/widgets/wallhaven_wall_card.dart';
import 'package:provider/provider.dart';

class WallsPage extends StatefulWidget {
  const WallsPage({Key? key}) : super(key: key);

  @override
  State<WallsPage> createState() => _WallsPageState();
}

class _WallsPageState extends State<WallsPage> {
  late ScrollController controller;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.addListener(() {
      if (controller.position.atEdge) {
        if (controller.position.pixels != 0) {
          if (context.read<WallHavenController>().searchState !=
              SearchState.busy) {
            context.read<WallHavenController>().page += 1;
            context.read<WallHavenController>().getSearchResults();
          }
        }
      }
      if (controller.position.userScrollDirection == ScrollDirection.forward) {
        if (context.read<HideController>().hidden) {
          logger.d("Show");
          context.read<HideController>().showBar();
        }
      } else if (controller.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (!context.read<HideController>().hidden) {
          logger.d("Hide");
          context.read<HideController>().hideBar();
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WallHavenWall>>(
      stream: context.read<WallHavenController>().wallSearchStream,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: () async {
            await context.read<WallHavenController>().clearSearchResults();
            await context.read<WallHavenController>().getSearchResults();
          },
          child: () {
            switch (context.watch<SettingsController>().wallDisplayMode) {
              case WallDisplayMode.comfortable:
                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 9 / 16,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  controller: controller,
                  itemCount: snapshot.data?.length ?? 0,
                  itemBuilder: (context, index) => WallHavenWallCard(
                    wallpaper: snapshot.data![index],
                  ),
                );
              case WallDisplayMode.immersive:
                return ListView.builder(
                  padding: const EdgeInsets.all(0),
                  controller: controller,
                  itemCount: snapshot.data?.length ?? 0,
                  itemBuilder: (context, index) => WallHavenImmersiveWallCard(
                      wallpaper: snapshot.data![index]),
                );
              default:
                // TODO: Add error page
                return Container();
            }
          }(),
        );
      },
    );
  }
}
