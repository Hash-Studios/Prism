enum StoreUpdate { none, suggested, required }

/// A store build below the Remote Config minimum build gets a store-update prompt. It blocks only when [blocking].
/// A Shorebird patch never changes the build number, so this rule ignores patches.
StoreUpdate storeUpdateFor({required String currentBuild, required int minBuild, required bool blocking}) {
  final int? build = int.tryParse(currentBuild.trim());
  if (build == null || minBuild <= 0 || build >= minBuild) return StoreUpdate.none;
  return blocking ? StoreUpdate.required : StoreUpdate.suggested;
}
