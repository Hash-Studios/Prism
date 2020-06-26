import 'package:flutter/material.dart';

class HeadingChipBar extends StatefulWidget {
  final String current;
  HeadingChipBar({Key key, @required this.current}) : super(key: key);

  @override
  _HeadingChipBarState createState() => _HeadingChipBarState();
}

class _HeadingChipBarState extends State<HeadingChipBar> {
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: ActionChip(
                  pressElevation: 5,
                  padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                  backgroundColor: Theme.of(context).accentColor,
                  label: Text(widget.current,
                      style: Theme.of(context)
                          .textTheme
                          .headline4
                          .copyWith(color: Theme.of(context).primaryColor)),
                  onPressed: () {}),
            ),
          )),
    );
  }
}
