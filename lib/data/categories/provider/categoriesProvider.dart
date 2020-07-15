import 'package:flutter/cupertino.dart';

class CategoryProvider extends ChangeNotifier {
  List<String> categories = [
    'Home',
    'Curated',
    'Colors',
    'For you',
    'Abstract',
    'Landscape',
    'Nature',
    '4K',
    'Art',
    'Pattern',
    'Minimal',
    'Anime',
    'Textures',
    'Technology',
    'Monochrome',
    'Code',
    'Space',
    'Cars',
    'Animals',
    'Skyscape',
    'Neon',
    'Architecture',
    'Sports',
    'Marvel',
    'Music',
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
