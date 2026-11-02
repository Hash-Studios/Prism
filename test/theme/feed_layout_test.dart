import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact density gives 3 columns on a small phone and caps at 8', () {
    expect(WallGridDensity.compact.columnsFor(375), 3); // small iPhone, portrait
    expect(WallGridDensity.compact.columnsFor(440), 3); // iPhone Pro Max, portrait
    expect(WallGridDensity.compact.columnsFor(956), 7); // iPhone Pro Max, landscape
    expect(WallGridDensity.compact.columnsFor(820), 6); // iPad Air, portrait
    expect(WallGridDensity.compact.columnsFor(1376), 8); // iPad Pro 13, landscape
    expect(WallGridDensity.compact.columnsFor(3000), 8); // capped
  });

  test('comfortable density gives 2 columns on a phone and caps at 8', () {
    expect(WallGridDensity.comfortable.columnsFor(375), 2); // small iPhone, portrait
    expect(WallGridDensity.comfortable.columnsFor(440), 2); // iPhone Pro Max, portrait
    expect(WallGridDensity.comfortable.columnsFor(956), 5); // iPhone Pro Max, landscape
    expect(WallGridDensity.comfortable.columnsFor(820), 4); // iPad Air, portrait
    expect(WallGridDensity.comfortable.columnsFor(1376), 7); // iPad Pro 13, landscape
    expect(WallGridDensity.comfortable.columnsFor(3000), 8); // capped
  });

  test('large density gives 1 column on a phone and caps at 8', () {
    expect(WallGridDensity.large.columnsFor(375), 1); // small iPhone, portrait
    expect(WallGridDensity.large.columnsFor(440), 1); // iPhone Pro Max, portrait
    expect(WallGridDensity.large.columnsFor(956), 2); // iPhone Pro Max, landscape
    expect(WallGridDensity.large.columnsFor(820), 2); // iPad Air, portrait
    expect(WallGridDensity.large.columnsFor(1376), 3); // iPad Pro 13, landscape
    expect(WallGridDensity.large.columnsFor(3000), 8); // capped
  });
}
