import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategoriesBar extends StatelessWidget {
  CategoriesBar({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      excludeHeaderSemantics: false,
      automaticallyImplyLeading: false,
      elevation: 0,
      titleSpacing: 0,
      title: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: Provider.of<CategoryProvider>(context).categories.length,
          itemBuilder: (context, index) {
            return Align(
              alignment: Alignment.center,
              child: Stack(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: ActionChip(
                        pressElevation: 5,
                        padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                        backgroundColor: index == 0
                            ? Theme.of(context).accentColor
                            : Theme.of(context).hintColor,
                        label: Text(
                            Provider.of<CategoryProvider>(context)
                                .categories[index],
                            style: index == 0
                                ? Theme.of(context)
                                    .textTheme
                                    .headline4
                                    .copyWith(
                                        color: Theme.of(context).primaryColor)
                                : Theme.of(context).textTheme.headline4),
                        onPressed: () {}),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
