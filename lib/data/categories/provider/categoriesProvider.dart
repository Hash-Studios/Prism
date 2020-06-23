import 'package:flutter/cupertino.dart';

class CategoryProvider extends ChangeNotifier {
  final List<String> categories = [
    'Home',
    'Curated',
    'Abstract',
    'Nature',
    'Red',
    'Blue',
    'Green'
  ];
  String selectedCategory = 'Home';
  void updateSelectedCategory(String newCategory) {
    this.selectedCategory = newCategory;
    notifyListeners();
  }
}
