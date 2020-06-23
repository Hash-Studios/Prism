import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/routing_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategoriesBar extends StatelessWidget {
  final String current;
  CategoriesBar({Key key, @required this.current}) : super(key: key);

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
                        backgroundColor: Provider.of<CategoryProvider>(context)
                                    .categories[index] ==
                                current
                            ? Theme.of(context).accentColor
                            : Theme.of(context).hintColor,
                        label: Text(
                            Provider.of<CategoryProvider>(context)
                                .categories[index],
                            style: Provider.of<CategoryProvider>(context)
                                        .categories[index] ==
                                    current
                                ? Theme.of(context)
                                    .textTheme
                                    .headline4
                                    .copyWith(
                                        color: Theme.of(context).primaryColor)
                                : Theme.of(context).textTheme.headline4),
                        onPressed: () {
                          if (current == "Home") {
                            if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Home") {
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Curated") {
                              Navigator.pushNamed(context, CuratedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Abstract") {
                              Navigator.pushNamed(context, AbstractRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Nature") {
                              Navigator.pushNamed(context, NatureRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Red") {
                              Navigator.pushNamed(context, RedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Blue") {
                              Navigator.pushNamed(context, BlueRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Green") {
                              Navigator.pushNamed(context, GreenRoute);
                            }
                          } else if (current == "Curated") {
                            if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Home") {
                              Navigator.pop(context);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Curated") {
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Abstract") {
                              Navigator.pushReplacementNamed(
                                  context, AbstractRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Nature") {
                              Navigator.pushReplacementNamed(
                                  context, NatureRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Red") {
                              Navigator.pushReplacementNamed(context, RedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Blue") {
                              Navigator.pushReplacementNamed(
                                  context, BlueRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Green") {
                              Navigator.pushReplacementNamed(
                                  context, GreenRoute);
                            }
                          } else if (current == "Abstract") {
                            if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Home") {
                              Navigator.pop(context);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Curated") {
                              Navigator.pushReplacementNamed(
                                  context, CuratedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Abstract") {
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Nature") {
                              Navigator.pushReplacementNamed(
                                  context, NatureRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Red") {
                              Navigator.pushReplacementNamed(context, RedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Blue") {
                              Navigator.pushReplacementNamed(
                                  context, BlueRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Green") {
                              Navigator.pushReplacementNamed(
                                  context, GreenRoute);
                            }
                          } else if (current == "Nature") {
                            if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Home") {
                              Navigator.pop(context);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Curated") {
                              Navigator.pushReplacementNamed(
                                  context, CuratedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Abstract") {
                              Navigator.pushReplacementNamed(
                                  context, AbstractRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Nature") {
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Red") {
                              Navigator.pushReplacementNamed(context, RedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Green") {
                              Navigator.pushReplacementNamed(
                                  context, GreenRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Blue") {
                              Navigator.pushReplacementNamed(
                                  context, BlueRoute);
                            }
                          } else if (current == "Red") {
                            if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Home") {
                              Navigator.pop(context);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Curated") {
                              Navigator.pushReplacementNamed(
                                  context, CuratedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Abstract") {
                              Navigator.pushReplacementNamed(
                                  context, AbstractRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Nature") {
                              Navigator.pushReplacementNamed(
                                  context, NatureRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Red") {
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Blue") {
                              Navigator.pushReplacementNamed(
                                  context, BlueRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Green") {
                              Navigator.pushReplacementNamed(
                                  context, GreenRoute);
                            }
                          } else if (current == "Blue") {
                            if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Home") {
                              Navigator.pop(context);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Curated") {
                              Navigator.pushReplacementNamed(
                                  context, CuratedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Abstract") {
                              Navigator.pushReplacementNamed(
                                  context, AbstractRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Nature") {
                              Navigator.pushReplacementNamed(
                                  context, NatureRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Red") {
                              Navigator.pushReplacementNamed(context, RedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Blue") {
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Green") {
                              Navigator.pushReplacementNamed(
                                  context, GreenRoute);
                            }
                          } else if (current == "Green") {
                            if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Home") {
                              Navigator.pop(context);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Curated") {
                              Navigator.pushReplacementNamed(
                                  context, CuratedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Abstract") {
                              Navigator.pushReplacementNamed(
                                  context, AbstractRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Nature") {
                              Navigator.pushReplacementNamed(
                                  context, NatureRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Red") {
                              Navigator.pushReplacementNamed(context, RedRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Blue") {
                              Navigator.pushReplacementNamed(
                                  context, BlueRoute);
                            } else if (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index] ==
                                "Green") {}
                          }
                        }),
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
