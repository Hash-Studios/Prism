class PublicProfilePage<T> {
  const PublicProfilePage({required this.items, required this.hasMore, this.nextCursor});

  final List<T> items;
  final bool hasMore;
  final String? nextCursor;
}
