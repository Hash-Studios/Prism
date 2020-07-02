import 'package:flutter/cupertino.dart';

class CategoryProvider extends ChangeNotifier {
  final List<String> categories = [
    'Home',
    'Curated',
    'Abstract',
    'Nature',
    'Colors',
  ];
  String selectedCategory = 'Home';
  void updateSelectedCategory(String newCategory) {
    this.selectedCategory = newCategory;
    Future.delayed(Duration(seconds: 0)).then((value) {
      super.notifyListeners();
    });
  }
}
