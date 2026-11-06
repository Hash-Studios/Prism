import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:flutter_test/flutter_test.dart';

FolderSaveWall _prism(String id) => FolderSaveWall(id: id, source: WallpaperSource.prism);

FolderSaveWall _wallhaven(String id) =>
    FolderSaveWall(id: id, source: WallpaperSource.wallhaven, link: 'https://w.wallhaven.cc/full/aa/wallhaven-$id.jpg');

FolderSaveAccount _account({
  bool isPro = false,
  bool premiumUnlocked = false,
  int balance = 100,
  int graceLeft = 0,
  int price = 10,
}) => FolderSaveAccount(
  isPro: isPro,
  premiumUnlocked: premiumUnlocked,
  balance: balance,
  graceLeft: graceLeft,
  price: price,
);

FolderSavePlan _build({
  required List<FolderSaveWall> walls,
  Map<String, WallAccess> access = const <String, WallAccess>{},
  required FolderSaveAccount account,
  Set<String> saved = const <String>{},
}) => FolderSavePlan.build(
  walls: walls,
  access: access,
  account: account,
  isSaved: (FolderSaveWall wall) => saved.contains(wall.key),
);

void main() {
  test('an open Prism wall for a free user with no grace costs coins', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('p1')],
      access: const <String, WallAccess>{'p1': WallAccess.open},
      account: _account(),
    );

    expect(plan.items.single.kind, FolderSaveKind.coins);
    expect(plan.items.single.cost, 10);
  });

  test('a bundled starter is free without consuming grace for a regular wall', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('starter-sunset'), _prism('p1')],
      access: const <String, WallAccess>{'p1': WallAccess.open},
      account: _account(graceLeft: 1),
    );

    expect(plan.items.map((item) => item.kind), <FolderSaveKind>[FolderSaveKind.free, FolderSaveKind.free]);
    expect(plan.totalCost, 0);
    expect(plan.blockedCount, 0);
  });

  test('a premium Prism wall is pro only for a free user and free for a premium unlock', () {
    const Map<String, WallAccess> access = <String, WallAccess>{'p1': WallAccess.premium};

    final FolderSavePlan locked = _build(walls: <FolderSaveWall>[_prism('p1')], access: access, account: _account());
    final FolderSavePlan unlocked = _build(
      walls: <FolderSaveWall>[_prism('p1')],
      access: access,
      account: _account(premiumUnlocked: true),
    );

    expect(locked.items.single.kind, FolderSaveKind.proOnly);
    expect(locked.items.single.cost, 0);
    expect(unlocked.items.single.kind, FolderSaveKind.free);
    expect(unlocked.items.single.cost, 0);
  });

  test('a Pro user saves open, premium and wallhaven walls at no cost', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('p1'), _prism('p2'), _wallhaven('w1')],
      access: const <String, WallAccess>{'p1': WallAccess.open, 'p2': WallAccess.premium},
      account: _account(isPro: true, premiumUnlocked: true),
    );

    expect(plan.items.map((FolderSaveItem item) => item.kind).toList(), <FolderSaveKind>[
      FolderSaveKind.free,
      FolderSaveKind.free,
      FolderSaveKind.free,
    ]);
    expect(plan.totalCost, 0);
    expect(plan.walls(FolderSaveChoice.all).map((FolderSaveItem item) => item.wall.id).toList(), <String>[
      'p1',
      'p2',
      'w1',
    ]);
  });

  test('protected and missing Prism walls are blocked, and a missing one is removed', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('p1'), _prism('p2')],
      access: const <String, WallAccess>{'p1': WallAccess.protected},
      account: _account(),
    );

    expect(plan.items[0].kind, FolderSaveKind.protected);
    expect(plan.items[1].kind, FolderSaveKind.removed);
    expect(plan.blockedCount, 2);
  });

  test('a saved wall stays saved even when its access is premium and it is unlocked', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('p1'), _prism('p2')],
      access: const <String, WallAccess>{'p1': WallAccess.premium, 'p2': WallAccess.open},
      account: _account(premiumUnlocked: true),
      saved: const <String>{'prism:p1'},
    );

    expect(plan.items[0].kind, FolderSaveKind.saved);
    expect(plan.walls(FolderSaveChoice.all).map((FolderSaveItem item) => item.wall.id).toList(), <String>['p2']);
    expect(plan.walls(FolderSaveChoice.freeOnly), isEmpty);
  });

  test('grace downloads go to the first walls in folder order', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3'), _prism('p4')],
      access: const <String, WallAccess>{
        'p1': WallAccess.open,
        'p2': WallAccess.open,
        'p3': WallAccess.open,
        'p4': WallAccess.open,
      },
      account: _account(graceLeft: 2),
    );

    expect(plan.items.map((FolderSaveItem item) => item.wall.id).toList(), <String>['p1', 'p2', 'p3', 'p4']);
    expect(plan.items.map((FolderSaveItem item) => item.kind).toList(), <FolderSaveKind>[
      FolderSaveKind.free,
      FolderSaveKind.free,
      FolderSaveKind.coins,
      FolderSaveKind.coins,
    ]);
  });

  test('a wallhaven wall is priced like an open Prism wall and needs no access entry', () {
    final FolderSavePlan plan = _build(walls: <FolderSaveWall>[_wallhaven('w1')], account: _account());

    expect(plan.items.single.kind, FolderSaveKind.coins);
    expect(plan.items.single.cost, 10);
  });

  test('the coin total is the price of every coin wall', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3')],
      access: const <String, WallAccess>{'p1': WallAccess.open, 'p2': WallAccess.open, 'p3': WallAccess.open},
      account: _account(),
    );

    expect(plan.count(FolderSaveKind.coins), 3);
    expect(plan.totalCost, 30);
  });

  test('a balance of 25 covers the first two coin walls in folder order', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('p1'), _prism('p2'), _prism('p3'), _prism('p4')],
      access: const <String, WallAccess>{
        'p1': WallAccess.open,
        'p2': WallAccess.premium,
        'p3': WallAccess.open,
        'p4': WallAccess.open,
      },
      account: _account(premiumUnlocked: true, balance: 25),
    );

    expect(plan.affordable.map((FolderSaveItem item) => item.wall.id).toList(), <String>['p1', 'p3']);
    expect(plan.affordableCost, 20);
    expect(plan.walls(FolderSaveChoice.all).map((FolderSaveItem item) => item.wall.id).toList(), <String>[
      'p1',
      'p2',
      'p3',
    ]);
    expect(plan.walls(FolderSaveChoice.freeOnly).map((FolderSaveItem item) => item.wall.id).toList(), <String>['p2']);
  });

  test('a duplicate wall with the same id and source appears once', () {
    final FolderSavePlan plan = _build(
      walls: <FolderSaveWall>[_prism('p1'), _prism('p1')],
      access: const <String, WallAccess>{'p1': WallAccess.open},
      account: _account(),
    );

    expect(plan.items, hasLength(1));
    expect(plan.items.single.wall.id, 'p1');
  });

  test('28 walls: 23 free, 2 coin, 3 premium, with a balance of 20', () {
    final List<FolderSaveWall> walls = <FolderSaveWall>[
      for (int i = 1; i <= 23; i++) _prism('f$i'),
      _prism('c1'),
      _prism('c2'),
      _prism('v1'),
      _prism('v2'),
      _prism('v3'),
    ];
    final Map<String, WallAccess> access = <String, WallAccess>{
      for (int i = 1; i <= 23; i++) 'f$i': WallAccess.open,
      'c1': WallAccess.open,
      'c2': WallAccess.open,
      'v1': WallAccess.premium,
      'v2': WallAccess.premium,
      'v3': WallAccess.premium,
    };

    final FolderSavePlan plan = _build(walls: walls, access: access, account: _account(graceLeft: 23, balance: 20));

    expect(plan.items, hasLength(28));
    expect(plan.count(FolderSaveKind.free), 23);
    expect(plan.count(FolderSaveKind.coins), 2);
    expect(plan.count(FolderSaveKind.proOnly), 3);
    expect(plan.totalCost, 20);
    expect(plan.walls(FolderSaveChoice.freeOnly), hasLength(23));
    expect(plan.walls(FolderSaveChoice.all), hasLength(25));
  });
}
