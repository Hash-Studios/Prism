import 'package:Prism/auth/userModel.dart';
import 'package:Prism/data/user/user_service.dart';
import 'package:Prism/locator/locator.dart';
import 'package:flutter/material.dart';

class UserNotifier with ChangeNotifier {
  final _userService = locator<UserService>();

  Stream<List<PrismUsersV2>> get sessionsStream => _userService.sessionsStream;

  UserDiscoveryState? get state =>
      _userService.userDiscoveryStateStream.valueOrNull;

  UserNotifier() {
    _userService.userDiscoveryStateStream.listen((event) {
      notifyListeners();
    });
  }
}
