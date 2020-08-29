import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoadingCardsCollection extends StatefulWidget {
  const LoadingCardsCollection({
    Key key,
  }) : super(key: key);

  @override
  _LoadingCardsCollectionState createState() => _LoadingCardsCollectionState();
}

class _LoadingCardsCollectionState extends State<LoadingCardsCollection>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = Provider.of<ThemeModel>(context, listen: false).returnTheme() ==
            ThemeType.Dark
        ? TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white10,
                  end: Color(0x22FFFFFF),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Color(0x22FFFFFF),
                  end: Colors.white10,
                ),
              ),
            ],
          ).animate(_controller)
        : TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.black12.withOpacity(.1),
                  end: Colors.black.withOpacity(.14),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.black.withOpacity(.14),
                  end: Colors.black.withOpacity(.1),
                ),
              ),
            ],
          ).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.repeat();
  }

  @override
  dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScrollController controller;
    try {
      controller = InheritedDataProvider.of(context).scrollController;
    } catch (e) {}

    return controller != null
        ? GridView.builder(
            controller: controller,
            padding: EdgeInsets.fromLTRB(5, 0, 5, 4),
            itemCount: 11,
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    MediaQuery.of(context).orientation == Orientation.portrait
                        ? 20000
                        : 20000,
                childAspectRatio: 1 / 0.6625,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: animation.value,
                ),
              );
            },
          )
        : GridView.builder(
            padding: EdgeInsets.fromLTRB(5, 0, 5, 4),
            itemCount: 24,
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    MediaQuery.of(context).orientation == Orientation.portrait
                        ? 20000
                        : 20000,
                childAspectRatio: 1 / 0.6625,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: animation.value,
                ),
              );
            },
          );
  }
}
