import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

class LoadingSetupCards extends StatefulWidget {
  const LoadingSetupCards({super.key});

  @override
  _LoadingSetupCardsState createState() => _LoadingSetupCardsState();
}

class _LoadingSetupCardsState extends State<LoadingSetupCards> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation = context.prismModeStyleForWindow(listen: false) == "Dark"
        ? TweenSequence<Color?>([
            TweenSequenceItem(
              weight: 1.0,
              tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)),
            ),
            TweenSequenceItem(
              weight: 1.0,
              tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10),
            ),
          ]).animate(_controller)
        : TweenSequence<Color?>([
            TweenSequenceItem(
              weight: 1.0,
              tween: ColorTween(
                begin: Colors.black12.withValues(alpha: .1),
                end: Colors.black.withValues(alpha: .14),
              ),
            ),
            TweenSequenceItem(
              weight: 1.0,
              tween: ColorTween(
                begin: Colors.black.withValues(alpha: .14),
                end: Colors.black.withValues(alpha: .1),
              ),
            ),
          ]).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScrollController? controller;
    try {
      if (InheritedDataProvider.of(context) != null) {
        controller = InheritedDataProvider.of(context)!.scrollController;
      }
    } catch (e) {
      logger.d(e.toString());
    }

    return controller != null
        ? GridView.builder(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
            itemCount: 24,
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
              childAspectRatio: 0.5025,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: animation.value),
              );
            },
          )
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
            itemCount: 24,
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
              childAspectRatio: 0.5025,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: animation.value),
              );
            },
          );
  }
}
