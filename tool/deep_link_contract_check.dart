import 'dart:io';

import 'package:Prism/core/router/deep_link_route_catalog.dart';

void main() {
  const List<DeepLinkRouteExample> examples = DeepLinkRouteCatalog.examples;
  if (examples.isEmpty) {
    throw StateError('DeepLinkRouteCatalog.examples must not be empty');
  }

  for (final DeepLinkRouteExample example in examples) {
    if (Uri.parse(example.uri).path == '/') continue; // The website, not a universal link, owns the home page.
    final DeepLinkRouteMatch? match = DeepLinkRouteCatalog.match(Uri.parse(example.uri));
    if (match == null || match.target != example.target) {
      throw StateError('Catalog example did not resolve to ${example.target}: ${example.uri}');
    }
  }

  stdout.writeln('Deep-link Dart catalog passed: ${examples.length} examples.');
}
