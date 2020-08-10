import 'package:flutter/cupertino.dart';

class TabProvider extends ChangeNotifier {
  List<String> tabs = [
    'Wallpapers',
    'Collections',
  ];
  String selectedTab = 'Wallpapers';
  void updateSelectedTab(String newTab) {
    this.selectedTab = newTab;
    Future.delayed(Duration(seconds: 0)).then((value) {
      super.notifyListeners();
    });
  }

  void updateTabs(List<String> newTab) {
    this.tabs = newTab;
    Future.delayed(Duration(seconds: 0)).then((value) {
      super.notifyListeners();
    });
  }
}
