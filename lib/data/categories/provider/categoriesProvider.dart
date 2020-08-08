import 'package:flutter/cupertino.dart';

class CategoryProvider extends ChangeNotifier {
  List<String> categories = [
    'Home',
    'Collection',
  ];
  String selectedCategory = 'Home';
  void updateSelectedCategory(String newCategory) {
    this.selectedCategory = newCategory;
    Future.delayed(Duration(seconds: 0)).then((value) {
      super.notifyListeners();
    });
  }

  void updateCategories(List<String> newCategory) {
    this.categories = newCategory;
    Future.delayed(Duration(seconds: 0)).then((value) {
      super.notifyListeners();
    });
  }
}
