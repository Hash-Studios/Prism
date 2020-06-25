import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/routing_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class CategoriesBar extends StatefulWidget {
  final String current;
  CategoriesBar({Key key, @required this.current}) : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  List<Color> colors = [
    Color(0xFFFF0000),
    Color(0xFFF44436),
    Color(0xFFe91e63),
    Color(0xFF9c27b0),
    Color(0xFF673ab7),
    Color(0xFF0000FF),
    Color(0xFF1976D2),
    Color(0xFF03a9f4),
    Color(0xFF00bcd4),
    Color(0xFF009688),
    Color(0xFF4caf50),
    Color(0xFF00FF00),
    Color(0xFF8bc34a),
    Color(0xFFcddc39),
    Color(0xFFffeb3b),
    Color(0xFFffc107),
    Color(0xFFff9800),
    Color(0xFFff5722),
    Color(0xFF795548),
    Color(0xFF9e9e9e),
    Color(0xFF607d8b),
    Color(0xFF000000),
    Color(0xFFFFFFFF)
  ];
  Color currentColor = Color(0xFFFF0000);

  @override
  Widget build(BuildContext context) {
    // Provider.of<CategoryProvider>(context).categories.remove(widget.current);
    // Provider.of<CategoryProvider>(context).categories.insert(0, widget.current);
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
                                widget.current
                            ? Theme.of(context).accentColor
                            : Theme.of(context).hintColor,
                        label: Text(
                            Provider.of<CategoryProvider>(context)
                                .categories[index],
                            style: Provider.of<CategoryProvider>(context)
                                        .categories[index] ==
                                    widget.current
                                ? Theme.of(context)
                                    .textTheme
                                    .headline4
                                    .copyWith(
                                        color: Theme.of(context).primaryColor)
                                : Theme.of(context).textTheme.headline4),
                        onPressed: () {
                          if (widget.current == "Home") {
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
                                "Colors") {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Select a color'),
                                    content: SingleChildScrollView(
                                      child: BlockPicker(
                                        availableColors: colors,
                                        pickerColor: currentColor,
                                        onColorChanged: (Color color) =>
                                            setState(() {
                                          currentColor = color;
                                          Navigator.pop(context);
                                          Navigator.pushNamed(
                                            context,
                                            ColorRoute,
                                            arguments: [
                                              currentColor
                                                  .toString()
                                                  .replaceAll(
                                                      "MaterialColor(primary value: Color(0xff",
                                                      "")
                                                  .replaceAll("Color(0xff", "")
                                                  .replaceAll(")", ""),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          } else if (widget.current == "Curated") {
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
                                "Colors") {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Select a color'),
                                    content: SingleChildScrollView(
                                      child: BlockPicker(
                                        availableColors: colors,
                                        pickerColor: currentColor,
                                        onColorChanged: (Color color) =>
                                            setState(() {
                                          currentColor = color;
                                          Navigator.pop(context);
                                          Navigator.pushReplacementNamed(
                                            context,
                                            ColorRoute,
                                            arguments: [
                                              currentColor
                                                  .toString()
                                                  .replaceAll(
                                                      "MaterialColor(primary value: Color(0xff",
                                                      "")
                                                  .replaceAll("Color(0xff", "")
                                                  .replaceAll(")", ""),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          } else if (widget.current == "Abstract") {
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
                                "Colors") {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Select a color'),
                                    content: SingleChildScrollView(
                                      child: BlockPicker(
                                        availableColors: colors,
                                        pickerColor: currentColor,
                                        onColorChanged: (Color color) =>
                                            setState(() {
                                          currentColor = color;
                                          Navigator.pop(context);
                                          Navigator.pushReplacementNamed(
                                            context,
                                            ColorRoute,
                                            arguments: [
                                              currentColor
                                                  .toString()
                                                  .replaceAll(
                                                      "MaterialColor(primary value: Color(0xff",
                                                      "")
                                                  .replaceAll("Color(0xff", "")
                                                  .replaceAll(")", ""),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          } else if (widget.current == "Nature") {
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
                                "Colors") {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Select a color'),
                                    content: SingleChildScrollView(
                                      child: BlockPicker(
                                        availableColors: colors,
                                        pickerColor: currentColor,
                                        onColorChanged: (Color color) =>
                                            setState(() {
                                          currentColor = color;
                                          Navigator.pop(context);
                                          Navigator.pushReplacementNamed(
                                            context,
                                            ColorRoute,
                                            arguments: [
                                              currentColor
                                                  .toString()
                                                  .replaceAll(
                                                      "MaterialColor(primary value: Color(0xff",
                                                      "")
                                                  .replaceAll("Color(0xff", "")
                                                  .replaceAll(")", ""),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          } else if (widget.current == "Colors") {
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
                                "Colors") {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Select a color'),
                                    content: SingleChildScrollView(
                                      child: BlockPicker(
                                        availableColors: colors,
                                        pickerColor: currentColor,
                                        onColorChanged: (Color color) =>
                                            setState(() {
                                          currentColor = color;
                                          Navigator.pop(context);
                                          Navigator.pushReplacementNamed(
                                            context,
                                            ColorRoute,
                                            arguments: [
                                              currentColor
                                                  .toString()
                                                  .replaceAll(
                                                      "MaterialColor(primary value: Color(0xff",
                                                      "")
                                                  .replaceAll("Color(0xff", "")
                                                  .replaceAll(")", ""),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
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
