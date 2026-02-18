import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/core/widgets/premiumBanners/setupOld.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/setups/views/setups_bloc_adapter.dart';
import 'package:Prism/features/setups/views/widgets/arrow_animation.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@RoutePage()
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController controller = PageController(viewportFraction: 0.78);
  Future? future;

  @override
  void initState() {
    future = context.setupsAdapter(listen: false).getSetups();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: BottomBar(
        child: SafeArea(
          top: false,
          child: SetupPage(future: future, controller: controller),
        ),
      ),
    );
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.future, required this.controller});

  final Future? future;
  final PageController controller;

  @override
  _SetupPageState createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  int pageNumber = 0;
  void showPremiumPopUp(Function func) {
    if (globals.prismUser.loggedIn == false) {
      googleSignInPopUp(context, () {
        if (globals.prismUser.premium == false) {
          context.router.push(const UpgradeRoute());
        } else {
          func();
        }
      });
    } else {
      if (globals.prismUser.premium == false) {
        context.router.push(const UpgradeRoute());
      } else {
        func();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<SetupSnapshot> setups = context.setupsAdapter().setups ?? const <SetupSnapshot>[];
    final bool hasSetups = setups.isNotEmpty;
    final int currentPage = hasSetups ? pageNumber.clamp(0, setups.length - 1) : 0;

    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        Positioned(
          top: 0,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.error, Theme.of(context).primaryColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 1],
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: MediaQuery.of(context).size.width - 25,
                padding: EdgeInsets.only(left: 25, top: 5 + globals.notchSize!),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        hasSetups ? setups[currentPage]['name'].toString().toUpperCase() : "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displayLarge!.copyWith(fontSize: 30),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const CoinBalanceChip(sourceTag: 'coins.chip.setup_screen'),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.12),
          child: FutureBuilder(
            future: widget.future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  snapshot.connectionState == ConnectionState.none) {
                logger.d("snapshot none, waiting");
                return Center(child: Loader());
              } else {
                return SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height * 0.9,
                  child: PageView.builder(
                    onPageChanged: (value) {
                      setState(() {
                        pageNumber = value;
                      });
                      if (hasSetups && pageNumber + 1 == setups.length) {
                        context.setupsAdapter(listen: false).seeMoreSetups();
                      }
                    },
                    controller: widget.controller,
                    itemCount: hasSetups ? setups.length : 1,
                    itemBuilder: (context, index) => !hasSetups
                        ? Loader()
                        : GestureDetector(
                            onTap: () {
                              if (index >= 5) {
                                showPremiumPopUp(() {
                                  context.router.push(SetupViewRoute(arguments: [index]));
                                });
                              } else {
                                context.router.push(SetupViewRoute(arguments: [index]));
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.only(
                                top: pageNumber == index + 1 || pageNumber == index - 1
                                    ? MediaQuery.of(context).size.height * 0.12
                                    : MediaQuery.of(context).size.height * 0.0499,
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: CachedNetworkImage(
                                  imageUrl: setups[index]['image'].toString(),
                                  imageBuilder: (context, imageProvider) => Container(
                                    width: MediaQuery.of(context).size.height * 0.7 * (9 / 19.5),
                                    height: MediaQuery.of(context).size.height * 0.7,
                                    decoration: BoxDecoration(
                                      boxShadow: pageNumber == index
                                          ? context.prismModeStyleForContext() == "Light"
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: .15),
                                                      blurRadius: 38,
                                                      offset: const Offset(0, 19),
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: .10),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 15),
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: .7),
                                                      blurRadius: 38,
                                                      offset: const Offset(0, 19),
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: .6),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 15),
                                                    ),
                                                  ]
                                          : [],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: PremiumBannerSetupOld(
                                      comparator: index < 5,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: MediaQuery.of(context).size.height * 0.7 * (9 / 19.5),
                                          height: MediaQuery.of(context).size.height * 0.7,
                                          child: Image(image: imageProvider, fit: BoxFit.fill),
                                        ),
                                      ),
                                    ),
                                  ),
                                  progressIndicatorBuilder: (context, url, downloadProgress) => SizedBox(
                                    width: MediaQuery.of(context).size.height * 0.7 * (9 / 19.5),
                                    height: MediaQuery.of(context).size.height * 0.7,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(
                                          context.prismModeStyleForContext() == "Dark" && context.prismIsAmoledDark()
                                              ? Theme.of(context).colorScheme.error == Colors.black
                                                    ? Theme.of(context).colorScheme.secondary
                                                    : Theme.of(context).colorScheme.error
                                              : Theme.of(context).colorScheme.error,
                                        ),
                                        value: downloadProgress.progress,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      JamIcons.close_circle_f,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                );
              }
            },
          ),
        ),
        if (pageNumber == 0)
          Container()
        else
          Align(
            alignment: Alignment.centerLeft,
            child: ArrowBounceAnimation(
              onTap: () {
                widget.controller.animateToPage(
                  widget.controller.page!.toInt() - 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.fastOutSlowIn,
                );
                HapticFeedback.vibrate();
              },
              child: Icon(
                JamIcons.chevron_left,
                color: context.prismModeStyleForContext() == "Dark" && context.prismIsAmoledDark()
                    ? Theme.of(context).colorScheme.error == Colors.black
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (!hasSetups || pageNumber >= setups.length - 1)
          Container()
        else
          Align(
            alignment: Alignment.centerRight,
            child: ArrowBounceAnimation(
              onTap: () {
                widget.controller.animateToPage(
                  widget.controller.page!.toInt() + 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.fastOutSlowIn,
                );
                HapticFeedback.vibrate();
              },
              child: Icon(
                JamIcons.chevron_right,
                color: context.prismModeStyleForContext() == "Dark" && context.prismIsAmoledDark()
                    ? Theme.of(context).colorScheme.error == Colors.black
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
