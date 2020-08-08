import 'package:flutter/cupertino.dart';

class CategoryProvider extends ChangeNotifier {
  List<String> categories = [
    'Wallpapers',
    'Collections',
  ];
  String selectedCategory = 'Wallpapers';
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
