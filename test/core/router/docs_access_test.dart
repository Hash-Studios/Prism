import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:Prism/core/router/route_access.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Set<RouteAccess>> _pageAccess(List<AutoRoute> routes, [String parent = '']) {
  final result = <String, Set<RouteAccess>>{};
  for (final route in routes.where((route) => route is! RedirectRoute)) {
    final path = route.path.startsWith('/')
        ? route.path
        : route.path.isEmpty
        ? parent
        : '$parent/${route.path}';
    result.putIfAbsent(path, () => {}).add(routeAccess[route.page.name]!);
    for (final entry in _pageAccess(route.children ?? [], path).entries) {
      result.putIfAbsent(entry.key, () => {}).addAll(entry.value);
    }
  }
  return result;
}

void main() {
  final doc = File('docs/features/deep-links.md').readAsStringSync();
  final section = doc.split('## Access\n')[1].split('\n## ').first;
  final rows = section.split('\n').where((line) => line.startsWith('| `/')).map((line) => line.split('|')).toList();

  test('documented Access paths agree with routeAccess and cover every page path', () {
    final documented = <String, RouteAccess>{};
    for (final row in rows) {
      final access = RouteAccess.values.byName(row[4].trim().toLowerCase());
      for (final match in RegExp('`([^`]+)`').allMatches(row[1])) {
        expect(documented.containsKey(match[1]), isFalse, reason: 'Duplicate Access path ${match[1]}');
        documented[match[1]!] = access;
      }
    }
    final actual = _pageAccess(AppRouter().routes);
    expect(documented.keys.toSet(), actual.keys.toSet());
    for (final entry in documented.entries) {
      expect(actual[entry.key], {entry.value}, reason: entry.key);
    }
  });

  test('Access table links point to the Access section', () {
    final links = RegExp(r'\[Access table\]\((#[^)]+)\)').allMatches(doc);
    expect(links, isNotEmpty);
    for (final link in links) {
      expect(link[1], '#access');
    }
  });

  test('every catalog target has exactly one documented Access row', () {
    final targets = rows.expand((row) => RegExp('`([^`]+)`').allMatches(row[2]).map((match) => match[1]!)).toList();
    expect(targets..sort(), DeepLinkPageTarget.values.map((target) => target.name).toList()..sort());
  });
}
