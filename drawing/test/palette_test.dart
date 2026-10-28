import 'package:drawing/floor_plan/editor/palette.dart';
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plan = FloorPlan.parse('''
    {"id": "p", "width": 20, "height": 10,
     "tables": [
       {"id": "T1", "shape": "rect", "x": 2, "y": 2, "width": 1, "height": 1},
       {"id": "T7", "shape": "rect", "x": 4, "y": 2, "width": 1, "height": 1},
       {"id": "BAR", "shape": "rect", "x": 6, "y": 2, "width": 1, "height": 1}
     ]}
  ''');

  test('a new table gets the next free number', () {
    final result = addPaletteItem(
      plan,
      PaletteItem.circleTable,
      const Offset(10, 5),
    );
    final table = result.plan.tables.last;

    expect(result.plan.tables, hasLength(4));
    expect(table.id, 'T8');
    expect(table.label, '8');
    expect(table.shape.shape, TableShape.circle);
    expect(table.seats, hasLength(4));
    expect(result.description, 'Table 8');
    // The original plan is unchanged.
    expect(plan.tables, hasLength(3));
  });

  test('every table shape gets seats', () {
    for (final item in PaletteItem.values.where((i) => i.tableShape != null)) {
      final table = addPaletteItem(
        plan,
        item,
        const Offset(10, 5),
      ).plan.tables.last;
      expect(table.seats, isNotEmpty, reason: item.name);
    }
  });

  test('positions round to one decimal and stay on the floor', () {
    final inside =
        addPaletteItem(
              plan,
              PaletteItem.plant,
              const Offset(3.34, 4.86),
            ).plan.elements.single
            as FixtureElement;
    expect(inside.x, closeTo(3.3, 1e-9));
    expect(inside.y, closeTo(4.9, 1e-9));

    final outside =
        addPaletteItem(
              plan,
              PaletteItem.plant,
              const Offset(-4, 99),
            ).plan.elements.single
            as FixtureElement;
    expect((outside.x, outside.y), (0.0, 10.0));
  });

  test('room & decor items add the right element', () {
    Object added(PaletteItem item) =>
        addPaletteItem(plan, item, const Offset(10, 5)).plan.elements.single;

    expect(added(PaletteItem.wall), isA<WallElement>());
    expect(
      added(PaletteItem.entranceDoor),
      isA<DoorElement>().having((d) => d.label, 'label', 'Entrance'),
    );
    expect(added(PaletteItem.window), isA<WindowElement>());
    expect(
      added(PaletteItem.fixture),
      isA<FixtureElement>().having((f) => f.label, 'label', 'Fixture'),
    );
  });

  test('windows can be read from JSON', () {
    final withWindow = FloorPlan.parse('''
      {"id": "p", "width": 10, "height": 10,
       "elements": [{"type": "window", "x": 5, "y": 0, "width": 3,
                     "orientation": "horizontal"}]}
    ''');
    final window = withWindow.elements.single as WindowElement;
    expect((window.x, window.width, window.angle), (5.0, 3.0, 0.0));
  });
}
