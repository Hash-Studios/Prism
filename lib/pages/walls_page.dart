import 'package:flutter/material.dart';
import 'package:prism/controllers/wallhaven_controller.dart';
import 'package:prism/model/wallhaven/wallhaven_search_state.dart';
import 'package:prism/model/wallhaven/wallhaven_wall_model.dart';
import 'package:prism/services/logger.dart';
import 'package:prism/widgets/inherited_container.dart';
import 'package:prism/widgets/scroll_navigation_bar_controller.dart';
import 'package:provider/provider.dart';
import 'package:scroll_app_bar/scroll_app_bar.dart';

class WallsPage extends StatefulWidget {
  const WallsPage({Key? key}) : super(key: key);

  @override
  State<WallsPage> createState() => _WallsPageState();
}

class _WallsPageState extends State<WallsPage> {
  late ScrollController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = InheritedContainer.of(context)!.controller;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Snap(
      controller: controller.bottomNavigationBar,
      child: StreamBuilder<List<WallHavenWall>>(
          stream: context.read<WallHavenController>().wallSearchStream,
          builder: (context, snapshot) {
            return RefreshIndicator(
              onRefresh: () async {
                await context.read<WallHavenController>().clearSearchResults();
                await context.read<WallHavenController>().getSearchResults();
              },
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                ),
                controller: controller,
                itemCount: snapshot.data?.length ?? 0,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () {
                    logger.d('Tapped on ${snapshot.data?[index].url}');
                  },
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 100,
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : Image.network(
                              snapshot.data?[index].thumbs.small ?? '',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ),
            );
          }),
    );
  }
}
