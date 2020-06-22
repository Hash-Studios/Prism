import 'package:flutter/cupertino.dart';

class CategoryProvider extends ChangeNotifier {
  final List<String> categories = [
    'Home',
    'Curated',
    'Abstract',
    'Community',
    'Nature',
    'Cars',
    'Comics',
  ];
  String selectedCategory = 'Home';
  void updateSelectedCategory(String newCategory) {
    this.selectedCategory = newCategory;
    notifyListeners();
  }
}
