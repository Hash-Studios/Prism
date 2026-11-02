/// The creator's approved wall that a new upload is a colour variant of. The upload sends only [wallDocId]; the server
/// checks it and owns the set.
final class VariantSeed {
  const VariantSeed({required this.wallDocId, required this.thumbnailUrl, this.title});

  final String wallDocId;
  final String thumbnailUrl;
  final String? title;
}
