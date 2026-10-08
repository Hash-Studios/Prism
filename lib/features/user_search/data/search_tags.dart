import 'package:Prism/data/categories/category_definition.dart';

/// Quick tags on the Search tab. They are the classifier categories, then a few styles. The order never changes.
final List<String> curatedSearchTags = List<String>.unmodifiable(<String>[
  ...prismClassifierCategories,
  'AMOLED',
  'Pastel',
  'Cityscape',
]);
