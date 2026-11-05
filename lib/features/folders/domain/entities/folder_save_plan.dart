import 'package:Prism/core/wallpaper/wallpaper_source.dart';

/// A wall that Save all can save, from a folder of the user or from a public folder the user follows.
class FolderSaveWall {
  const FolderSaveWall({required this.id, required this.source, this.link = '', this.label});

  final String id;
  final WallpaperSource source;

  /// The full url. Empty for a protected Prism wall, whose original comes only from a server grant.
  final String link;

  /// Names the coin history row of the spend: the title, or "Wallpaper by" and the creator.
  final String? label;

  /// The Downloads key. The Save pill of the wall uses the same key, so its page shows Saved after Save all.
  String get identity => link.isEmpty ? '$id.jpg' : link;

  String get key => '${source.name}:$id';
}

/// What the server lets a viewer do with a Prism wall right now.
enum WallAccess {
  open,

  /// In a premium collection.
  premium,

  /// A streak or Drop wall. It needs its own unlock.
  protected,

  /// Deleted, held for review, or without a protected original.
  removed,
}

/// What Save all does with one wall.
enum FolderSaveKind {
  free,
  coins,
  proOnly,
  protected,
  removed,

  /// Already in Downloads.
  saved,
}

class FolderSaveItem {
  const FolderSaveItem({required this.wall, required this.kind, this.cost = 0})
    : assert(cost == 0 || kind == FolderSaveKind.coins, 'Only a coin wall has a cost.');

  final FolderSaveWall wall;
  final FolderSaveKind kind;

  /// Coins the wall costs. Zero unless [kind] is [FolderSaveKind.coins].
  final int cost;
}

/// The two buttons of the plan sheet. A Pro user only has [all].
enum FolderSaveChoice { freeOnly, all }

/// The account facts that price a folder. Read once, before the plan is shown.
class FolderSaveAccount {
  const FolderSaveAccount({
    required this.isPro,
    required this.premiumUnlocked,
    required this.balance,
    required this.graceLeft,
    required this.price,
  });

  /// Pro saves every wall the server opens at no cost.
  final bool isPro;

  /// Pro or a premium pass: premium walls are free.
  final bool premiumUnlocked;
  final int balance;

  /// Free downloads left. The server gives them to the first downloads it sees.
  final int graceLeft;

  /// The coin price of one wall that is not premium.
  final int price;
}

/// Every wall of a folder, with what Save all does with it. Built before any download and shown to the user.
class FolderSavePlan {
  const FolderSavePlan._(this.items, this.account);

  /// [access] holds the Prism walls the server still serves. A Prism wall missing from it is [WallAccess.removed].
  /// [isSaved] is true for a wall that is already in Downloads.
  factory FolderSavePlan.build({
    required List<FolderSaveWall> walls,
    required Map<String, WallAccess> access,
    required FolderSaveAccount account,
    required bool Function(FolderSaveWall wall) isSaved,
  }) {
    int graceLeft = account.graceLeft;
    FolderSaveItem paid(FolderSaveWall wall) {
      if (account.isPro) return FolderSaveItem(wall: wall, kind: FolderSaveKind.free);
      if (graceLeft > 0) {
        graceLeft--;
        return FolderSaveItem(wall: wall, kind: FolderSaveKind.free);
      }
      return FolderSaveItem(wall: wall, kind: FolderSaveKind.coins, cost: account.price);
    }

    final Set<String> seen = <String>{};
    final List<FolderSaveItem> items = <FolderSaveItem>[
      for (final FolderSaveWall wall in walls)
        if (seen.add(wall.key))
          if (isSaved(wall))
            FolderSaveItem(wall: wall, kind: FolderSaveKind.saved)
          else if (wall.source != WallpaperSource.prism)
            paid(wall)
          else
            switch (access[wall.id] ?? WallAccess.removed) {
              WallAccess.open => paid(wall),
              WallAccess.premium => FolderSaveItem(
                wall: wall,
                kind: account.premiumUnlocked ? FolderSaveKind.free : FolderSaveKind.proOnly,
              ),
              WallAccess.protected => FolderSaveItem(wall: wall, kind: FolderSaveKind.protected),
              WallAccess.removed => FolderSaveItem(wall: wall, kind: FolderSaveKind.removed),
            },
    ];
    return FolderSavePlan._(List<FolderSaveItem>.unmodifiable(items), account);
  }

  final List<FolderSaveItem> items;
  final FolderSaveAccount account;

  bool get isPro => account.isPro;

  List<FolderSaveItem> of(FolderSaveKind kind) => items.where((item) => item.kind == kind).toList(growable: false);

  int count(FolderSaveKind kind) => items.where((item) => item.kind == kind).length;

  /// Protected and removed walls. Nobody can save them from a folder.
  int get blockedCount => count(FolderSaveKind.protected) + count(FolderSaveKind.removed);

  /// The coins of every coin wall.
  int get totalCost => of(FolderSaveKind.coins).fold(0, (sum, item) => sum + item.cost);

  /// The coin walls the balance covers, in folder order.
  List<FolderSaveItem> get affordable {
    int left = account.balance;
    final List<FolderSaveItem> covered = <FolderSaveItem>[];
    for (final FolderSaveItem item in of(FolderSaveKind.coins)) {
      if (item.cost > left) break;
      left -= item.cost;
      covered.add(item);
    }
    return covered;
  }

  int get affordableCost => affordable.fold(0, (sum, item) => sum + item.cost);

  /// The walls a choice saves, in folder order.
  List<FolderSaveItem> walls(FolderSaveChoice choice) {
    final Set<FolderSaveItem> paid = choice == FolderSaveChoice.all ? affordable.toSet() : const <FolderSaveItem>{};
    return items.where((item) => item.kind == FolderSaveKind.free || paid.contains(item)).toList(growable: false);
  }
}
