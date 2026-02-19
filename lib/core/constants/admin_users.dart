const Set<String> adminEmails = <String>{'akshaymaurya3006@gmail.com', 'maurya.abhay30@gmail.com'};

bool isAdminEmail(String? email) {
  final String target = (email ?? '').trim().toLowerCase();
  if (target.isEmpty) {
    return false;
  }
  return adminEmails.contains(target);
}
