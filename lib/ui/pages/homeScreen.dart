import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:flutter/material.dart';

class MainWidget extends StatelessWidget {
  MainWidget({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: PreferredSize(
          child: CategoriesBar(),
          preferredSize: Size(double.infinity, 60),
        ),
        body: Stack(alignment: Alignment.bottomCenter,
          children: [
            GridLoader(),
            Positioned(bottom: 10, child: BottomNavBar())
          ],
        ));
  }
}
