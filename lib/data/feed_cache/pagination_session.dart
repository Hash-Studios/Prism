/// Optional capability for feeds with short-lived, independently owned page cursors.
abstract interface class PaginationSession {
  void releasePaginationKey(String paginationKey);
}
