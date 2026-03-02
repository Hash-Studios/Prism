import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/features/profile_setups/views/profile_setups_bloc_adapter.dart';
import 'package:Prism/features/setups/views/widgets/loading_setup_cards.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palette_generator/palette_generator.dart';

class UploadedSetupsGrid extends StatefulWidget {
  const UploadedSetupsGrid({super.key});

  @override
  _UploadedSetupsGridState createState() => _UploadedSetupsGridState();
}

class _UploadedSetupsGridState extends State<UploadedSetupsGrid> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<Color?> animation;
  GlobalKey<RefreshIndicatorState> refreshProfileSetupKey = GlobalKey<RefreshIndicatorState>();
  PaletteGenerator? paletteGenerator;
  List<Color>? colors;
  bool seeMoreLoader = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation =
        context.prismModeStyleForWindow(listen: false) == "Dark"
              ? TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10),
                  ),
                ]).animate(_controller!)
              : TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .1),
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
                ]).animate(_controller!)
          ..addListener(() {
            setState(() {});
          });
    _controller!.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshProfileSetupKey.currentState?.show();
    context.profileSetupsAdapter(listen: false).getProfileSetups();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshProfileSetupKey,
      onRefresh: refreshList,
      child: context.profileSetupsAdapter(listen: false).profileSetups != null
          ? context.profileSetupsAdapter(listen: false).profileSetups!.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: context.prismModeStyleForContext() == "Dark"
                            ? SvgPicture.string(
                                postsDark
                                    .replaceAll(
                                      "181818",
                                      Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "E57697",
                                      Theme.of(
                                        context,
                                      ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                                    )
                                    .replaceAll(
                                      "F0F0F0",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2E41",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "3F3D56",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2F2F",
                                      Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2),
                                    ),
                              )
                            : SvgPicture.string(
                                postsLight
                                    .replaceAll(
                                      "181818",
                                      Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "E57697",
                                      Theme.of(
                                        context,
                                      ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                                    )
                                    .replaceAll(
                                      "F0F0F0",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2E41",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "3F3D56",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2F2F",
                                      Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2),
                                    ),
                              ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.1,
                      ),
                    ],
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
                    itemCount: context.profileSetupsAdapter().profileSetups!.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                      childAspectRatio: 0.5025,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      if (index == context.profileSetupsAdapter(listen: false).profileSetups!.length - 1 &&
                          !(context.profileSetupsAdapter(listen: false).profileSetups!.length < 8)) {
                        return SeeMoreButton(
                          seeMoreLoader: seeMoreLoader,
                          func: () {
                            if (!seeMoreLoader) {
                              setState(() {
                                seeMoreLoader = true;
                              });
                              context.profileSetupsAdapter(listen: false).seeMoreProfileSetups();
                              setState(() {
                                Future.delayed(const Duration(seconds: 1)).then((value) => seeMoreLoader = false);
                              });
                            }
                          },
                        );
                      }
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: animation.value,
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(
                                  context.profileSetupsAdapter().profileSetups![index]["image"].toString(),
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                onTap: () {
                                  if (context.profileSetupsAdapter(listen: false).profileSetups == []) {
                                  } else {
                                    context.router.push(ProfileSetupViewRoute(setupIndex: index));
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
          : const LoadingSetupCards(),
    );
  }
}
