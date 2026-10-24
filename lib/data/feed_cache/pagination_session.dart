/// Optional capability for feeds with short-lived, independently owned page cursors.
abstract interface class PaginationSession {
  void releasePaginationKey(String paginationKey);
}

/// Page keys with this prefix belong to one wallpaper detail visit. Their cursor stays in memory only: no snapshot
/// goes to the durable feed cache, and a failed first page never reads one back, so a later visit or launch cannot
/// show these pages again.
const String ephemeralPaginationPrefix = 'detail:';

bool isEphemeralPaginationKey(String paginationKey) => paginationKey.startsWith(ephemeralPaginationPrefix);
