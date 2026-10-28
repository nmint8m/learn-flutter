import 'dart:io';

import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:drawing/geometry/geometry_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FloorPlan.parse', () {
    test('the app\'s own floor plan file loads', () {
      // Whatever you've saved from the app: it must still be valid.
      final plan = FloorPlan.parse(
        File('assets/floor_plans/main_floor.json').readAsStringSync(),
      );
      expect(plan.width, greaterThan(0));
      expect(plan.floorOutline.length, greaterThanOrEqualTo(3));
    });

    // The rest use test/fixtures/main_floor.json, a fixed copy, so saving a
    // new design from the app doesn't change what the tests expect.
    test('reads the sample plan', () {
      final source = File('test/fixtures/main_floor.json').readAsStringSync();
      final plan = FloorPlan.parse(source);

      expect(plan.name, 'Main floor');
      expect(plan.width, 40);
      expect(plan.tables, hasLength(11));
      expect(plan.elements.whereType<WallElement>(), hasLength(1));
      // L-shaped room: 6 corners, with the top-left corner cut away.
      expect(plan.floorOutline, hasLength(6));
      expect(plan.elements.whereType<DoorElement>(), hasLength(2));

      final bar = plan.tableById('BAR')!;
      expect(bar.statusPerSeat, isTrue);
      expect(bar.seats.map((s) => s.id), ['BAR-1', 'BAR-2', 'BAR-3', 'BAR-4']);
      expect(plan.tableById('T1')!.statusPerSeat, isFalse);

      final booth = plan.tableById('B1')!;
      expect(booth.shape.shape, TableShape.semicircle);
      expect(booth.shape.side, SemicircleSide.left);
    });

    test('fills in defaults for optional fields', () {
      final plan = FloorPlan.parse('''
        {"id": "p", "width": 10, "height": 10,
         "tables": [{"id": "T1", "shape": "rect",
                     "x": 5, "y": 5, "width": 2, "height": 2}]}
      ''');
      final table = plan.tables.single;
      expect(table.label, 'T1');
      expect(table.rotation, 0);
      expect(table.seats, isEmpty);
      expect(plan.gridSize, 1);
      // No outline given: the floor is the whole rectangle.
      expect(plan.outline, isNull);
      expect(plan.floorOutline, const [
        Offset(0, 0),
        Offset(10, 0),
        Offset(10, 10),
        Offset(0, 10),
      ]);
    });

    test('names the bad field in the error', () {
      expect(
        () => FloorPlan.parse('''
          {"id": "p", "width": 10, "height": 10,
           "tables": [{"id": "T9", "shape": "triangle",
                       "x": 1, "y": 1, "width": 1, "height": 1}]}
        '''),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('T9'), contains('"shape"'), contains('triangle')),
          ),
        ),
      );
    });

    test('rejects duplicate table ids', () {
      const table =
          '{"id": "T1", "shape": "rect", "x": 1, "y": 1, "width": 1, "height": 1}';
      expect(
        () => FloorPlan.parse(
          '{"id": "p", "width": 10, "height": 10, "tables": [$table, $table]}',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects text that is not JSON', () {
      expect(() => FloorPlan.parse('not json'), throwsFormatException);
    });
  });

  group('SeatLayout', () {
    FloorTable table(SeatLayout seats) => FloorTable(
      id: 'T',
      label: 'T',
      shape: const ShapeSpec.rect(),
      x: 0,
      y: 0,
      width: 4,
      height: 2,
      seatLayout: seats,
    );

    test('places side seats just outside each edge', () {
      final seats = table(const SeatLayout(top: 2, right: 1)).seats;
      const out = SeatLayout.seatGap + SeatLayout.seatSize / 2;

      expect(seats.map((s) => s.offset), [
        const Offset(-1, -1 - out),
        const Offset(1, -1 - out),
        const Offset(2 + out, 0),
      ]);
      expect(seats.map((s) => s.id), ['T-1', 'T-2', 'T-3']);
    });

    test('spreads "around" seats evenly, starting at the top', () {
      final seats = table(const SeatLayout(around: 4)).seats;
      final first = seats.first.offset;
      expect(first.dx, closeTo(0, 1e-9));
      expect(first.dy, lessThan(0));
      expect(seats[2].offset.dy, closeTo(-first.dy, 1e-9));
    });
  });
}
