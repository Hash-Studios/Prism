import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:prism/controllers/hide_controller.dart';
import 'package:prism/controllers/setup_controller.dart';
import 'package:prism/model/setup/setup_model.dart';
import 'package:prism/services/logger.dart';
import 'package:prism/widgets/setup_card.dart';
import 'package:provider/provider.dart';

class SetupsPage extends StatefulWidget {
  const SetupsPage({Key? key}) : super(key: key);

  @override
  State<SetupsPage> createState() => _SetupsPageState();
}

class _SetupsPageState extends State<SetupsPage> {
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
      // if (controller.position.atEdge) {
      //   if (controller.position.pixels != 0) {
      //     if (context.read<SetupController>().searchState != SearchState.busy) {
      //       context.read<SetupController>().getSearchResults();
      //     }
      //   }
      // }
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
  Widget build(BuildContext context) {
    final ScrollController controller = ScrollController();
    return StreamBuilder<List<Setup>>(
        stream: context.read<SetupController>().setupSearchStream,
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: () async {
              await context.read<SetupController>().clearSearchResults();
              await context.read<SetupController>().getSearchResults();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(0),
              controller: controller,
              itemCount: snapshot.data?.length ?? 0,
              itemBuilder: (context, index) =>
                  SetupCard(snapshot: snapshot, index: index),
            ),
          );
        });
  }
}
