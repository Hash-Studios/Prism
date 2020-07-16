import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/global/globals.dart';
import 'package:Prism/ui/pages/categories/4KScreen.dart';
import 'package:Prism/ui/pages/categories/abstractScreen.dart';
import 'package:Prism/ui/pages/categories/animalsScreen.dart';
import 'package:Prism/ui/pages/categories/animeScreen.dart';
import 'package:Prism/ui/pages/categories/architectureScreen.dart';
import 'package:Prism/ui/pages/categories/artScreen.dart';
import 'package:Prism/ui/pages/categories/carsScreen.dart';
import 'package:Prism/ui/pages/categories/codeScreen.dart';
import 'package:Prism/ui/pages/categories/curatedScreen.dart';
import 'package:Prism/ui/pages/categories/forYouScreen.dart';
import 'package:Prism/ui/pages/categories/landscapeScreen.dart';
import 'package:Prism/ui/pages/categories/marvelScreen.dart';
import 'package:Prism/ui/pages/categories/minimalScreen.dart';
import 'package:Prism/ui/pages/categories/monochromeScreen.dart';
import 'package:Prism/ui/pages/categories/musicScreen.dart';
import 'package:Prism/ui/pages/categories/natureScreen.dart';
import 'package:Prism/ui/pages/categories/neonScreen.dart';
import 'package:Prism/ui/pages/categories/patternScreen.dart';
import 'package:Prism/ui/pages/categories/skyscapeScreen.dart';
import 'package:Prism/ui/pages/categories/spaceScreen.dart';
import 'package:Prism/ui/pages/categories/sportsScreen.dart';
import 'package:Prism/ui/pages/categories/technologyScreen.dart';
import 'package:Prism/ui/pages/categories/texturesScreen.dart';
import 'package:Prism/ui/pages/home/homeScreen.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/categoriesBar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

PageController pageController = PageController();

class PageManager extends StatefulWidget {
  @override
  _PageManagerState createState() => _PageManagerState();
}

class _PageManagerState extends State<PageManager> {
  int page = 0;
  @override
  void initState() {
    Provider.of<CategoryProvider>(context, listen: false)
        .updateSelectedCategory("Home");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (page != 0) {
          pageController.jumpTo(0);
        } else {
          return true;
        }
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: PreferredSize(
            child: CategoriesBar(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height),
            preferredSize: Size(double.infinity, 55),
          ),
          body: BottomBar(
            child: PageView.builder(
                onPageChanged: (index) {
                  print("Index cat: " + index.toString());
                  if (index < 2) {
                    setState(() {
                      page = index;
                    });
                    categoryController.scrollToIndex(index,
                        preferPosition: AutoScrollPosition.begin);
                  } else {
                    setState(() {
                      page = index + 1;
                    });
                    categoryController.scrollToIndex(index + 1,
                        preferPosition: AutoScrollPosition.begin);
                  }

                  if (index == 0) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Home");
                  } else if (index == 1) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Curated");
                  } else if (index == 2) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("For you");
                  } else if (index == 3) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Abstract");
                  } else if (index == 4) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Landscape");
                  } else if (index == 5) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Nature");
                  } else if (index == 6) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("4K");
                  } else if (index == 7) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Art");
                  } else if (index == 8) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Pattern");
                  } else if (index == 9) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Minimal");
                  } else if (index == 10) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Anime");
                  } else if (index == 11) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Textures");
                  } else if (index == 12) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Technology");
                  } else if (index == 13) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Monochrome");
                  } else if (index == 14) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Code");
                  } else if (index == 15) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Space");
                  } else if (index == 16) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Cars");
                  } else if (index == 17) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Animals");
                  } else if (index == 18) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Skyscape");
                  } else if (index == 19) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Neon");
                  } else if (index == 20) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Architecture");
                  } else if (index == 21) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Sports");
                  } else if (index == 22) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Marvel");
                  } else if (index == 23) {
                    Provider.of<CategoryProvider>(context, listen: false)
                        .updateSelectedCategory("Music");
                  }
                },
                controller: pageController,
                itemCount: 24,
                itemBuilder: (context, index) {
                  print("Index : " + index.toString());
                  if (index == 0) {
                    return HomeScreen();
                  } else if (index == 1) {
                    return CuratedScreen();
                  } else if (index == 2) {
                    return ForYouScreen();
                  } else if (index == 3) {
                    return AbstractScreen();
                  } else if (index == 4) {
                    return LandscapeScreen();
                  } else if (index == 5) {
                    return NatureScreen();
                  } else if (index == 6) {
                    return FourKScreen();
                  } else if (index == 7) {
                    return ArtScreen();
                  } else if (index == 8) {
                    return PatternScreen();
                  } else if (index == 9) {
                    return MinimalScreen();
                  } else if (index == 10) {
                    return AnimeScreen();
                  } else if (index == 11) {
                    return TexturesScreen();
                  } else if (index == 12) {
                    return TechnologyScreen();
                  } else if (index == 13) {
                    return MonochromeScreen();
                  } else if (index == 14) {
                    return CodeScreen();
                  } else if (index == 15) {
                    return SpaceScreen();
                  } else if (index == 16) {
                    return CarsScreen();
                  } else if (index == 17) {
                    return AnimalsScreen();
                  } else if (index == 18) {
                    return SkyscapeScreen();
                  } else if (index == 19) {
                    return NeonScreen();
                  } else if (index == 20) {
                    return ArchitectureScreen();
                  } else if (index == 21) {
                    return SportsScreen();
                  } else if (index == 22) {
                    return MarvelScreen();
                  } else if (index == 23) {
                    return MusicScreen();
                  }
                }),
          )),
    );
  }
}
