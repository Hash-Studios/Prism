import 'package:Prism/core/constants/app_constants.dart';

bool isAdminEmail(String? email) {
  final String target = (email ?? '').trim().toLowerCase();
  if (target.isEmpty) {
    return false;
  }
  return adminEmails.contains(target);
}
