import 'dart:io';
import 'dart:ui' show Rect;

import 'package:drawing/floor_plan/editor/floor_edits.dart';
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plan = FloorPlan.parse(
    File('test/fixtures/main_floor.json').readAsStringSync(),
  );
  final t1 = plan.tableById('T1')!;
  final doorIndex = plan.elements.indexWhere((e) => e is DoorElement);

  group('hitTestItem', () {
    test('finds a table only when looking for tables', () {
      final center = Offset(t1.x, t1.y);
      expect(hitTestItem(plan, center, tables: true), const TableRef('T1'));
      expect(hitTestItem(plan, center, tables: false), isNull);
    });

    test('misses the empty corner of a quarter-circle table', () {
      final corner = plan.tableById('C1')!;
      // The curve is at the bottom-right, so that corner of its box is empty.
      final emptyCorner = Offset(
        corner.x + corner.width / 2 - 0.2,
        corner.y + corner.height / 2 - 0.2,
      );
      expect(hitTestItem(plan, emptyCorner, tables: true), isNull);
    });

    test('finds a door on the wall', () {
      final door = plan.elements[doorIndex] as DoorElement;
      expect(
        hitTestItem(plan, Offset(door.x + 0.5, door.y), tables: false),
        ElementRef(doorIndex),
      );
    });
  });

  group('walls', () {
    test('tapping an outer wall selects that side of the room', () {
      // The bottom wall runs along y = 24.
      final ref = hitTestItem(plan, const Offset(10, 23.9), tables: false);
      expect(ref, isA<OutlineEdgeRef>());
      final points = wallPoints(plan, ref!)!;
      expect(points.map((p) => p.dy), [24, 24]);
      expect(canRename(ref), isFalse);
      expect(itemKind(plan, ref), startsWith('Outer wall · '));
    });

    test('an inner wall reports its start and end', () {
      final ref = hitTestItem(plan, const Offset(30, 5), tables: false);
      expect(ref, isA<ElementRef>());
      final points = wallPoints(plan, ref!)!;
      expect(points.first, const Offset(30, 0));
      expect(points.last, const Offset(40, 10));
      expect(itemKind(plan, ref), 'Wall · (30, 0) → (40, 10)');
    });

    test('moving an outer wall moves its two corners', () {
      final ref = hitTestItem(plan, const Offset(10, 23.9), tables: false)!;
      final before = wallPoints(plan, ref)!;
      final moved = moveItem(plan, ref, const Offset(0, -1));
      expect(wallPoints(moved, ref), [
        for (final p in before) p + const Offset(0, -1),
      ]);
      // The outline is saved with the plan.
      expect(FloorPlan.parse(moved.encode()).floorOutline, moved.floorOutline);
    });

    test('wallEndAt finds the nearest end within reach', () {
      final ref = hitTestItem(plan, const Offset(30, 5), tables: false)!;
      expect(wallEndAt(plan, ref, const Offset(30.3, 0.2), 1), WallEnd.start);
      expect(wallEndAt(plan, ref, const Offset(39.5, 10), 1), WallEnd.end);
      expect(wallEndAt(plan, ref, const Offset(30, 5), 1), isNull);
      expect(wallEndAt(plan, const TableRef('T1'), Offset.zero, 99), isNull);
    });

    test('moveWallEnd moves only that end of an inner wall', () {
      final ref = hitTestItem(plan, const Offset(30, 5), tables: false)!;
      final before = wallPoints(plan, ref)!;
      final after = wallPoints(
        snapWallEnd(
          moveWallEnd(plan, ref, WallEnd.end, const Offset(-2.23, 0.14)),
          ref,
          WallEnd.end,
        ),
        ref,
      )!;
      expect(after.last.dx, closeTo(before.last.dx - 2.2, 1e-9));
      expect(after.last.dy, closeTo(before.last.dy + 0.1, 1e-9));
      // The start and the corner in between stay put.
      expect(
        after.sublist(0, after.length - 1),
        before.sublist(0, before.length - 1),
      );
    });

    test('moving an outer wall end moves that room corner', () {
      final ref = hitTestItem(plan, const Offset(10, 23.9), tables: false)!;
      final before = wallPoints(plan, ref)!;
      final moved = moveWallEnd(plan, ref, WallEnd.start, const Offset(0, 1));
      final after = wallPoints(moved, ref)!;
      expect(after.first, before.first + const Offset(0, 1));
      expect(after.last, before.last);
      // The neighboring outer wall shares that corner, so it follows.
      expect(moved.floorOutline, contains(after.first));
      expect(moved.floorOutline, isNot(contains(before.first)));
    });

    test('doors and tables are not walls', () {
      expect(wallPoints(plan, ElementRef(doorIndex)), isNull);
      expect(wallPoints(plan, const TableRef('T1')), isNull);
    });
  });

  test('moveItem and snapItem round a table to one decimal', () {
    const ref = TableRef('T1');
    final moved = snapItem(
      moveItem(plan, ref, const Offset(2.23, -0.87)),
      ref,
    ).tableById('T1')!;
    expect(moved.x, closeTo(t1.x + 2.2, 1e-9));
    expect(moved.y, closeTo(t1.y - 0.9, 1e-9));
    // Nothing else changes.
    expect(moved.label, t1.label);
  });

  test('moveItem moves every point of a wall', () {
    final wallIndex = plan.elements.indexWhere((e) => e is WallElement);
    final before = plan.elements[wallIndex] as WallElement;
    final after =
        moveItem(
              plan,
              ElementRef(wallIndex),
              const Offset(1, 2),
            ).elements[wallIndex]
            as WallElement;
    for (var i = 0; i < before.points.length; i++) {
      expect(after.points[i], before.points[i] + const Offset(1, 2));
    }
  });

  group('removeItem', () {
    test('removes a table', () {
      final removed = removeItem(plan, const TableRef('T1'));
      expect(removed.tableById('T1'), isNull);
      expect(removed.tables, hasLength(plan.tables.length - 1));
    });

    test('removes a room element and keeps the others in order', () {
      final removed = removeItem(plan, ElementRef(doorIndex));
      expect(removed.elements, hasLength(plan.elements.length - 1));
      expect(removed.elements, [
        for (final (i, e) in plan.elements.indexed)
          if (i != doorIndex) e,
      ]);
    });

    test('leaves outer walls alone', () {
      expect(removeItem(plan, const OutlineEdgeRef(0)), same(plan));
    });
  });

  group('door and window length', () {
    test('is shown and set in meters', () {
      final door = ElementRef(doorIndex);
      expect(plan.metersPerUnit, 0.5);
      expect(itemLengthMeters(plan, door), 1.5);

      final resized = resizeItem(plan, door, 2);
      expect(itemLengthMeters(resized, door), 2);
      // Stored in floor units: 2 m / 0.5 m per unit.
      expect((resized.elements[doorIndex] as DoorElement).width, 4);
    });

    test('follows the plan\'s metersPerUnit', () {
      final metric = FloorPlan.parse('''
        {"id": "p", "width": 10, "height": 10, "metersPerUnit": 1,
         "elements": [{"type": "window", "x": 5, "y": 0, "width": 3}]}
      ''');
      expect(itemLengthMeters(metric, const ElementRef(0)), 3);
      expect(itemKind(metric, const ElementRef(0)), 'Window · 3 m');
      // Saved and read back.
      expect(FloorPlan.parse(metric.encode()).metersPerUnit, 1);
    });

    test('only doors and windows have a length', () {
      expect(itemLengthMeters(plan, const TableRef('T1')), isNull);
      expect(itemLengthMeters(plan, const OutlineEdgeRef(0)), isNull);
      expect(resizeItem(plan, const TableRef('T1'), 2), same(plan));
    });
  });

  group('resizeFixture', () {
    final kitchenIndex = plan.elements.indexWhere(
      (e) => e is FixtureElement && e.label == 'Kitchen',
    );
    final plantIndex = plan.elements.indexWhere(
      (e) => e is FixtureElement && e.label == null,
    );

    test('sets width and height in meters, keeping the center', () {
      final kitchen = ElementRef(kitchenIndex);
      expect(itemSizeMeters(plan, kitchen), (
        width: 4.8,
        height: 4.8,
        round: false,
      ));
      final resized = resizeFixture(plan, kitchen, width: 3);
      final f = resized.elements[kitchenIndex] as FixtureElement;
      expect((f.width, f.height), (6, 9.6));
      expect((f.x, f.y), (35, 5));
      expect(itemKind(resized, kitchen), 'Fixture · 3 × 4.8 m');
    });

    test('a round fixture stays round', () {
      final plant = ElementRef(plantIndex);
      expect(itemSizeMeters(plan, plant)?.round, isTrue);
      final resized = resizeFixture(plan, plant, height: 1);
      final f = resized.elements[plantIndex] as FixtureElement;
      expect((f.width, f.height), (2, 2));
      expect(itemKind(resized, plant), 'Plant / round fixture · ⌀ 1 m');
    });

    test('only fixtures have a size', () {
      expect(itemSizeMeters(plan, ElementRef(doorIndex)), isNull);
      expect(itemSizeMeters(plan, const TableRef('T1')), isNull);
      expect(resizeFixture(plan, ElementRef(doorIndex), width: 2), same(plan));
    });
  });

  group('roomBounds', () {
    test('is the floor when the walls stay on it', () {
      expect(roomBounds(plan), const Rect.fromLTRB(0, 0, 40, 24));
    });

    test('takes in walls past the floor, but not tables', () {
      final wide = FloorPlan.parse('''
        {"id": "p", "width": 40, "height": 24,
         "outline": [[0, 0], [47, 0], [47, 24], [0, 24]],
         "elements": [{"type": "wall", "points": [[10, -2], [10, 5]]}],
         "tables": [{"id": "T1", "label": "1", "shape": "rect",
                     "x": 20, "y": 25, "width": 2, "height": 2}]}
      ''');
      expect(roomBounds(wide), const Rect.fromLTRB(0, -2, 47, 24));
    });
  });

  group('planContentBounds', () {
    test('is the floor when everything fits on it', () {
      expect(planContentBounds(plan), const Rect.fromLTRB(0, 0, 40, 24));
    });

    test('takes in walls and tables past the floor', () {
      final wide = FloorPlan.parse('''
        {"id": "p", "width": 40, "height": 24,
         "outline": [[0, 0], [47, 0], [47, 24], [0, 24]],
         "tables": [{"id": "T1", "label": "1", "shape": "rect",
                     "x": 20, "y": 25, "width": 2, "height": 2}]}
      ''');
      final bounds = planContentBounds(wide);
      expect(bounds.right, 47);
      expect(bounds.bottom, 26);
      expect(bounds.topLeft, Offset.zero);
    });
  });

  group('duplicateItem', () {
    test('copies elements 0.2 m right and down, and selects the copy', () {
      final kitchenIndex = plan.elements.indexWhere(
        (e) => e is FixtureElement && e.label == 'Kitchen',
      );
      final (copied, ref) = duplicateItem(plan, ElementRef(kitchenIndex))!;
      expect(ref, ElementRef(plan.elements.length));
      final original = plan.elements[kitchenIndex] as FixtureElement;
      final copy = copied.elements.last as FixtureElement;
      expect((copy.x, copy.y), (original.x + 0.4, original.y + 0.4));
      expect(copy.label, 'Kitchen');
      expect((copy.width, copy.height), (original.width, original.height));
    });

    test('a copied wall moves all its points', () {
      final wallIndex = plan.elements.indexWhere((e) => e is WallElement);
      final (copied, _) = duplicateItem(plan, ElementRef(wallIndex))!;
      final original = plan.elements[wallIndex] as WallElement;
      final copy = copied.elements.last as WallElement;
      expect(copy.points, [
        for (final p in original.points) p + const Offset(0.4, 0.4),
      ]);
    });

    test('a copied door stays on its wall, moved along it', () {
      final (copied, ref) = duplicateItem(plan, ElementRef(doorIndex))!;
      final original = plan.elements[doorIndex] as DoorElement;
      final copy = copied.elements.last as DoorElement;
      // The entrance is on the bottom wall (y = 24): it can only move right.
      expect(copy.y, original.y);
      expect(copy.x, closeTo(original.x + 0.4, 1e-9));
      expect(openingWall(copied, (ref as ElementRef).index)?.id, isNotNull);
    });

    test('a copied table gets the next id and number', () {
      final (copied, ref) = duplicateItem(plan, const TableRef('T1'))!;
      expect(ref, const TableRef('T8'));
      expect(copied.tableById('T8')!.label, '8');
    });

    test('follows the plan\'s metersPerUnit', () {
      final metric = FloorPlan.parse('''
        {"id": "p", "width": 10, "height": 10, "metersPerUnit": 1,
         "elements": [{"type": "fixture", "shape": "rect",
                       "x": 5, "y": 5, "width": 1, "height": 1}]}
      ''');
      final (copied, _) = duplicateItem(metric, const ElementRef(0))!;
      final copy = copied.elements.last as FixtureElement;
      expect((copy.x, copy.y), (5.2, 5.2));
    });

    test('outer walls can\'t be duplicated', () {
      expect(duplicateItem(plan, const OutlineEdgeRef(0)), isNull);
      expect(canDuplicateOrRemove(const OutlineEdgeRef(0)), isFalse);
    });
  });

  group('seat sides and rotation', () {
    // T5 is a 6 × 2.5 rounded rectangle with 3 top, 3 bottom, 1 left, 1 right.
    const t5 = TableRef('T5');

    test('only rounded rectangle and square tables have sides', () {
      expect(sidedTable(plan, t5), isNotNull);
      expect(sidedTable(plan, const TableRef('T2')), isNull); // Circle.
      expect(sidedTable(plan, ElementRef(doorIndex)), isNull);
    });

    test('switching a side off and on keeps nothing, then the default', () {
      final off = setSeatSide(plan, t5, SeatSide.top, included: false);
      expect(off.tableById('T5')!.seatLayout.top, 0);
      expect(off.tableById('T5')!.seats, hasLength(5));
      final on = setSeatSide(off, t5, SeatSide.top, included: true);
      expect(on.tableById('T5')!.seatLayout.top, 2); // Rectangle default.
    });

    test('switching on a side that has seats keeps their number', () {
      final same = setSeatSide(plan, t5, SeatSide.top, included: true);
      expect(same.tableById('T5')!.seatLayout.top, 3);
    });

    test('a square table gets one seat per side', () {
      final square = FloorPlan.parse('''
        {"id": "p", "width": 10, "height": 10,
         "tables": [{"id": "T1", "label": "1", "shape": "roundedRect",
                     "x": 5, "y": 5, "width": 3, "height": 3}]}
      ''');
      final on = setSeatSide(
        square,
        const TableRef('T1'),
        SeatSide.top,
        included: true,
      );
      expect(on.tableById('T1')!.seatLayout.top, 1);
    });

    test('rotation stays within 0–360', () {
      expect(rotateTable(plan, t5, 90).tableById('T5')!.rotation, 90);
      expect(rotateTable(plan, t5, 375).tableById('T5')!.rotation, 15);
      expect(rotateTable(plan, t5, -15).tableById('T5')!.rotation, 345);
      // Saved and read back.
      final saved = FloorPlan.parse(rotateTable(plan, t5, 45).encode());
      expect(saved.tableById('T5')!.rotation, 45);
    });
  });

  group('tables inside the room', () {
    test('which tables are outside the L-shaped room', () {
      // C1, T1, T2 and T3 sit in the L's cut-out (above y = 12, left of 26).
      expect(
        tablesOutsideRoom(plan).map((t) => t.id),
        containsAll(['C1', 'T1', 'T2']),
      );
      expect(tableInsideRoom(plan, plan.tableById('T6')!), isTrue);
    });

    test('seats count: a table whose seats cross the wall is outside', () {
      final t6 = plan.tableById('T6')!; // Round, 3.5 across, at (25, 19.5).
      // 1.75 + seats (0.15 gap + 0.8 seat) ≈ 2.7 from the center: at
      // y = 21.5 the seats reach past the wall at 24.
      final low = t6.copyWith(y: 21.5);
      expect(tableInsideRoom(plan, low), isFalse);
    });

    test('a turned table is checked as turned', () {
      final square = FloorPlan.parse('''
        {"id": "p", "width": 10, "height": 10,
         "tables": [{"id": "T1", "label": "1", "shape": "rect",
                     "x": 5, "y": 1.3, "width": 2, "height": 2}]}
      ''');
      final t = square.tableById('T1')!;
      expect(tableInsideRoom(square, t), isTrue);
      // Turned 45°, its corners reach 1.41 up: past the wall at y = 0.
      expect(tableInsideRoom(square, t.copyWith(rotation: 45)), isFalse);
    });

    test('moves into a wall slide along it, or stop', () {
      const t6 = TableRef('T6');
      final down = moveItemInsideRoom(plan, t6, const Offset(0, 10));
      expect(down.tableById('T6')!.y, 19.5); // Can't go down at all.
      final slide = moveItemInsideRoom(plan, t6, const Offset(2, 10));
      expect(slide.tableById('T6')!.x, 27); // Only the sideways part.
    });

    test('a table already outside moves freely, to be brought in', () {
      final moved = moveItemInsideRoom(
        plan,
        const TableRef('T1'),
        const Offset(0, 5),
      );
      expect(moved.tableById('T1')!.y, 15);
    });

    test('placeTableInsideRoom finds the nearest spot inside', () {
      final placed = placeTableInsideRoom(plan, 'T2'); // At (10.5, 4).
      final t2 = placed.tableById('T2')!;
      expect(tableInsideRoom(placed, t2), isTrue);
      expect(t2.x, closeTo(10.5, 0.01)); // Straight down is nearest.
      expect(t2.y, greaterThan(12));
      // A table already inside stays put.
      expect(placeTableInsideRoom(plan, 'T6'), same(plan));
    });
  });

  group('bars', () {
    final withBar = FloorPlan.parse('''
      {"id": "p", "width": 40, "height": 24,
       "tables": [{"id": "T1", "label": "Bar", "shape": "roundedRect",
                   "x": 20, "y": 12, "width": 8, "height": 2,
                   "seats": {"bottom": 4}, "statusPerSeat": true,
                   "bar": true}]}
    ''');
    const ref = TableRef('T1');

    test('read and written as a bar', () {
      expect(barTable(withBar, ref), isNotNull);
      expect(sidedTable(withBar, ref), isNull);
      final again = FloorPlan.parse(withBar.encode());
      expect(again.tableById('T1')!.bar, isTrue);
      // Older plans without "bar" aren't bars.
      expect(barTable(plan, const TableRef('BAR')), isNull);
    });

    test('setBarSeats keeps one row and the center', () {
      final six = setBarSeats(withBar, ref, 6).tableById('T1')!;
      expect(six.seatLayout.bottom, 6);
      expect(six.seatLayout.top + six.seatLayout.left, 0);
      expect(six.width, 12);
      expect((six.x, six.y), (20, 12));
      // Clamped to 1–10.
      expect(setBarSeats(withBar, ref, 15).tableById('T1')!.seats.length, 10);
      expect(setBarSeats(withBar, ref, 0).tableById('T1')!.seats.length, 1);
    });

    test('a duplicated bar is still a bar', () {
      final (copied, copy) = duplicateItem(withBar, ref)!;
      expect(barTable(copied, copy), isNotNull);
    });
  });

  test('renameItem changes the name', () {
    final renamed = renameItem(plan, ElementRef(doorIndex), 'Front door');
    expect(itemName(renamed, ElementRef(doorIndex)), 'Front door');
    // The entrance is 3 units wide; 1 unit is 0.5 m by default.
    expect(itemKind(renamed, ElementRef(doorIndex)), 'Door · 1.5 m');
  });

  test('positions are saved with one decimal, sizes with two', () {
    final door = ElementRef(doorIndex);
    final edited = resizeItem(
      moveItem(plan, door, const Offset(0.1234, 0)),
      door,
      1.33,
    );
    final saved =
        FloorPlan.parse(edited.encode()).elements[doorIndex] as DoorElement;
    expect(saved.x, 20.1); // 20.1234 → 20.1
    expect(saved.width, 2.66); // 1.33 m / 0.5 m per unit, kept exact
  });

  test('roundPosition rounds to the nearest tenth', () {
    expect(roundPosition(12.34), closeTo(12.3, 1e-9));
    expect(roundPosition(12.35), closeTo(12.4, 1e-9));
    expect(roundPosition(-0.04), closeTo(0, 1e-9));
  });

  test('a saved plan reads back the same', () {
    final edited = renameItem(
      moveItem(plan, const TableRef('T1'), const Offset(1, 0)),
      const TableRef('T1'),
      'Window',
    );
    final reread = FloorPlan.parse(edited.encode());

    expect(reread.encode(), edited.encode());
    expect(reread.tableById('T1')!.label, 'Window');
    expect(reread.tableById('T1')!.x, t1.x + 1);
    expect(reread.floorOutline, plan.floorOutline);
    expect(reread.tableById('BAR')!.statusPerSeat, isTrue);
  });
}
