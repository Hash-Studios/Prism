import 'dart:ui';

import 'package:Prism/data/profile/wallpaper/profileSetupProvider.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;

class UploadedSetupsGrid extends StatefulWidget {
  const UploadedSetupsGrid({
    Key key,
  }) : super(key: key);

  @override
  _UploadedSetupsGridState createState() => _UploadedSetupsGridState();
}

class _UploadedSetupsGridState extends State<UploadedSetupsGrid>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;
  GlobalKey<RefreshIndicatorState> refreshProfileSetupKey =
      GlobalKey<RefreshIndicatorState>();
  PaletteGenerator paletteGenerator;
  List<Color> colors;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = Provider.of<ThemeModel>(context, listen: false)
                .returnThemeType() ==
            "Dark"
        ? TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white10,
                  end: const Color(0x22FFFFFF),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: const Color(0x22FFFFFF),
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
                  begin: Colors.black.withOpacity(.1),
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
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Future<List<Color>> _updatePaletteGenerator(String link) async {
  //   paletteGenerator = await PaletteGenerator.fromImageProvider(
  //       CachedNetworkImageProvider(link),
  //       maximumColorCount: 5,
  //       region: Rect.fromLTRB(0, 0, 10, 10));
  //   colors = paletteGenerator.colors.toList();
  //   if (paletteGenerator.colors.length > 5) {
  //     colors = colors.sublist(0, 5);
  //   }
  //   return colors;
  // }

  Future<void> refreshList() async {
    refreshProfileSetupKey.currentState?.show();
    await Future.delayed(const Duration(milliseconds: 500));
    Provider.of<ProfileSetupProvider>(context, listen: false)
        .getProfileSetups();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshProfileSetupKey,
        onRefresh: refreshList,
        child: Provider.of<ProfileSetupProvider>(context, listen: false)
                    .profileSetups !=
                null
            ? Provider.of<ProfileSetupProvider>(context, listen: false)
                    .profileSetups
                    .isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: Provider.of<ThemeModel>(context, listen: false)
                                    .returnThemeType() ==
                                "Dark"
                            ? SvgPicture.string(
                                postsDark
                                    .replaceAll(
                                        "181818",
                                        Theme.of(context)
                                            .primaryColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "E57697",
                                        main.prefs
                                            .get("mainAccentColor")
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2F2F",
                                        Theme.of(context)
                                            .hintColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2)),
                              )
                            : SvgPicture.string(
                                postsLight
                                    .replaceAll(
                                        "181818",
                                        Theme.of(context)
                                            .primaryColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "E57697",
                                        main.prefs
                                            .get("mainAccentColor")
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2F2F",
                                        Theme.of(context)
                                            .hintColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2)),
                              ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.1,
                      )
                    ],
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    cacheExtent: 50000,
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
                    itemCount: Provider.of<ProfileSetupProvider>(context)
                        .profileSetups
                        .length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            MediaQuery.of(context).orientation ==
                                    Orientation.portrait
                                ? 300
                                : 250,
                        childAspectRatio: 0.5025,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          if (Provider.of<ProfileSetupProvider>(context,
                                      listen: false)
                                  .profileSetups ==
                              []) {
                          } else {
                            Navigator.pushNamed(context, profileSetupViewRoute,
                                arguments: [index]);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                              color: animation.value,
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    Provider.of<ProfileSetupProvider>(context)
                                        .profileSetups[index]["image"]
                                        .toString(),
                                  ),
                                  fit: BoxFit.cover)),
                        ),
                      );
                    })
            : const LoadingCards());
  }
}
