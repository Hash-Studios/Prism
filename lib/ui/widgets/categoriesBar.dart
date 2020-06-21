import 'package:flutter/material.dart';

class CategoriesBar extends StatelessWidget {
  const CategoriesBar({
    Key key,
    @required this.categories,
  }) : super(key: key);

  final List<String> categories;

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
          itemCount: categories.length,
          itemBuilder: (context, index) {
            return Align(
              alignment: Alignment.center,
              child: Stack(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(500),
                      color: index == 0
                          ? Theme.of(context).accentColor
                          : Theme.of(context).hintColor,
                    ),
                    margin: EdgeInsets.all(5),
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Text(categories[index],
                        style: index == 0
                            ? Theme.of(context)
                                .textTheme
                                .headline4
                                .copyWith(color: Theme.of(context).primaryColor)
                            : Theme.of(context).textTheme.headline4),
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
