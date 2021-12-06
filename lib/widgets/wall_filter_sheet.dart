import 'package:flutter/material.dart';
import 'package:prism/controllers/wallhaven_controller.dart';
import 'package:prism/model/wallhaven/wallhaven_order.dart';
import 'package:prism/model/wallhaven/wallhaven_sorting.dart';
import 'package:provider/provider.dart';

class WallFilterSheet extends StatelessWidget {
  const WallFilterSheet({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, controller) {
          return DefaultTabController(
            length: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: const TabBar(
                      tabs: [
                        Tab(
                          height: 54,
                          child:
                              Text('Display', style: TextStyle(fontSize: 12)),
                        ),
                        Tab(
                          height: 54,
                          child: Text('Filter', style: TextStyle(fontSize: 12)),
                        ),
                        Tab(
                          height: 54,
                          child: Text('Sort', style: TextStyle(fontSize: 12)),
                        )
                      ],
                      indicatorSize: TabBarIndicatorSize.label,
                    ),
                  ),
                  SizedBox(
                    height: (MediaQuery.of(context).size.height * 0.9) - 56,
                    child: TabBarView(
                      children: [
                        Container(),
                        FilterList(controller: controller),
                        SortList(controller: controller),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FilterList extends StatelessWidget {
  const FilterList({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      controller: controller,
      children: [
        const ListTile(
          title: Text("Category"),
          visualDensity: VisualDensity.compact,
          dense: true,
        ),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: context.watch<WallHavenController>().showGeneralCategory,
          onChanged: (value) {
            context.read<WallHavenController>().showGeneralCategory =
                value ?? true;
            context.read<WallHavenController>().updateCategory();
          },
          title: const Text('General'),
        ),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: context.watch<WallHavenController>().showAnimeCategory,
          onChanged: (value) {
            context.read<WallHavenController>().showAnimeCategory =
                value ?? true;
            context.read<WallHavenController>().updateCategory();
          },
          title: const Text('Anime'),
        ),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: context.watch<WallHavenController>().showPeopleCategory,
          onChanged: (value) {
            context.read<WallHavenController>().showPeopleCategory =
                value ?? true;
            context.read<WallHavenController>().updateCategory();
          },
          title: const Text('People'),
        ),
        const ListTile(
          title: Text("Purity"),
          visualDensity: VisualDensity.compact,
          dense: true,
        ),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: context.watch<WallHavenController>().showSFWPurity,
          onChanged: (value) {
            context.read<WallHavenController>().showSFWPurity = value ?? true;
            context.read<WallHavenController>().updatePurity();
          },
          title: const Text('SFW'),
        ),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: context.watch<WallHavenController>().showSketchyPurity,
          onChanged: (value) {
            context.read<WallHavenController>().showSketchyPurity =
                value ?? true;
            context.read<WallHavenController>().updatePurity();
          },
          title: const Text('Sketchy'),
        ),
      ],
    );
  }
}

class SortList extends StatelessWidget {
  const SortList({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      controller: controller,
      children: [
        for (final sorting in Sorting.values)
          ListTile(
            dense: true,
            title: Text(sorting.toText()),
            leading: context.watch<WallHavenController>().sorting == sorting
                ? sorting == Sorting.random
                    ? const Icon(Icons.shuffle)
                    : sorting == Sorting.toplist
                        ? const Icon(Icons.military_tech_outlined)
                        : context.watch<WallHavenController>().order ==
                                Order.desc
                            ? const Icon(Icons.arrow_downward)
                            : const Icon(Icons.arrow_upward)
                : const Icon(
                    Icons.close,
                    color: Colors.transparent,
                  ),
            onTap: () {
              if (context.read<WallHavenController>().sorting == sorting) {
                context.read<WallHavenController>().toggleOrder();
              } else {
                context.read<WallHavenController>().sorting = sorting;
              }
            },
          ),
      ],
    );
  }
}
