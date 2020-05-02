import 'package:flutter/material.dart';
import 'package:wallpapers_app/wallpapers.dart';

class Search extends StatefulWidget {
  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Search> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Hero(
          tag: 'search',
          child: Card(
            elevation: 0,
            color: Colors.transparent,
            child: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                }),
          ),
        ),
        title: TextField(
          onSubmitted: (String query) {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return Wallpapers(query);
            }));
          },
          decoration: InputDecoration(
            hintText: "Search",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
