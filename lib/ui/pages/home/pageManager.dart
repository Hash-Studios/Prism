import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/global/globals.dart';
import 'package:Prism/ui/pages/categories/abstractScreen.dart';
import 'package:Prism/ui/pages/categories/animalsScreen.dart';
import 'package:Prism/ui/pages/categories/artScreen.dart';
import 'package:Prism/ui/pages/categories/curatedScreen.dart';
import 'package:Prism/ui/pages/categories/minimalScreen.dart';
import 'package:Prism/ui/pages/categories/monochromeScreen.dart';
import 'package:Prism/ui/pages/categories/musicScreen.dart';
import 'package:Prism/ui/pages/categories/natureScreen.dart';
import 'package:Prism/ui/pages/categories/neonScreen.dart';
import 'package:Prism/ui/pages/categories/spaceScreen.dart';
import 'package:Prism/ui/pages/categories/sportsScreen.dart';
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
  @override
  void initState() {
    Provider.of<CategoryProvider>(context, listen: false)
        .updateSelectedCategory("Home");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: PreferredSize(
          child: CategoriesBar(),
          preferredSize: Size(double.infinity, 55),
        ),
        body: BottomBar(
          child: PageView.builder(
              onPageChanged: (index) {
                print("Index cat: " + index.toString());
                if (index < 2) {
                  categoryController.scrollToIndex(index,
                      preferPosition: AutoScrollPosition.begin);
                } else {
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
                      .updateSelectedCategory("Abstract");
                } else if (index == 3) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Nature");
                } else if (index == 4) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Art");
                } else if (index == 5) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Minimal");
                } else if (index == 6) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Textures");
                } else if (index == 7) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Monochrome");
                } else if (index == 8) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Space");
                } else if (index == 9) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Animals");
                } else if (index == 10) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Neon");
                } else if (index == 11) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Sports");
                } else if (index == 12) {
                  Provider.of<CategoryProvider>(context, listen: false)
                      .updateSelectedCategory("Music");
                }
              },
              controller: pageController,
              itemCount: 13,
              itemBuilder: (context, index) {
                print("Index : " + index.toString());
                if (index == 0) {
                  return HomeScreen();
                } else if (index == 1) {
                  return CuratedScreen();
                } else if (index == 2 && index != 3) {
                  return AbstractScreen();
                } else if (index == 3) {
                  return NatureScreen();
                } else if (index == 4) {
                  return ArtScreen();
                } else if (index == 5) {
                  return MinimalScreen();
                } else if (index == 6) {
                  return TexturesScreen();
                } else if (index == 7) {
                  return MonochromeScreen();
                } else if (index == 8) {
                  return SpaceScreen();
                } else if (index == 9) {
                  return AnimalsScreen();
                } else if (index == 10) {
                  return NeonScreen();
                } else if (index == 11) {
                  return SportsScreen();
                } else if (index == 12) {
                  return MusicScreen();
                }
              }),
        ));
  }
}
