import 'package:Prism/ui/widgets/categoriesBar.dart';
import 'package:flutter/material.dart';

class MainWidget extends StatelessWidget {
  MainWidget({
    Key key,
  }) : super(key: key);

  final categories = [
    'Home',
    'Abstract',
    'Nature',
    'Comics',
    'Cars',
    'Community'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: PreferredSize(
          child: CategoriesBar(categories: categories),
          preferredSize: Size(double.infinity, 60),
        ));
  }
}
