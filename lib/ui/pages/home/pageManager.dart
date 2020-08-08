import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/global/globals.dart';
import 'package:Prism/ui/pages/collectionScreen.dart';
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
                        .updateSelectedCategory("Collection");
                  }
                },
                controller: pageController,
                itemCount: 24,
                itemBuilder: (context, index) {
                  print("Index : " + index.toString());
                  if (index == 0) {
                    return HomeScreen();
                  } else if (index == 1) {
                    return CollectionScreen();
                  }
                }),
          )),
    );
  }
}
