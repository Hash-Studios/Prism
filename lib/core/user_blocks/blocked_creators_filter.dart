/// Filters Prism-hosted content by blocked creator email (normalized lowercase).
class BlockedCreatorsFilter {
  BlockedCreatorsFilter._();

  static String normalizeEmail(String? email) => (email ?? '').trim().toLowerCase();

  static bool hidesCreatorEmail(String? creatorEmail, Set<String> blockedEmailsLowercase) {
    if (blockedEmailsLowercase.isEmpty) {
      return false;
    }
    final String n = normalizeEmail(creatorEmail);
    return n.isNotEmpty && blockedEmailsLowercase.contains(n);
  }
}
