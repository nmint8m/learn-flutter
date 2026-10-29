import 'dart:io';
import 'dart:ui' show Rect;

import 'package:drawing/floor_plan/editor/floor_edits.dart';
import 'package:drawing/geometry/geometry_paths.dart' show QuarterCircleCorner;
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

    test('switching a side off and on matches the opposite side', () {
      final off = setSeatSide(plan, t5, SeatSide.top, included: false);
      expect(off.tableById('T5')!.seatLayout.top, 0);
      expect(off.tableById('T5')!.seats, hasLength(5));
      final on = setSeatSide(off, t5, SeatSide.top, included: true);
      // Back on: as many as the opposite (bottom) side.
      expect(on.tableById('T5')!.seatLayout.top, 3);
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
      expect(rotateItem(plan, t5, 90).tableById('T5')!.rotation, 90);
      expect(rotateItem(plan, t5, 375).tableById('T5')!.rotation, 15);
      expect(rotateItem(plan, t5, -15).tableById('T5')!.rotation, 345);
      // Saved and read back.
      final saved = FloorPlan.parse(rotateItem(plan, t5, 45).encode());
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
      expect(six.width, closeTo(7.2, 1e-9)); // 6 × 0.6 m.
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

  test('rotateItem turns fixtures too, and is saved', () {
    final kitchenIndex = plan.elements.indexWhere(
      (e) => e is FixtureElement && e.label == 'Kitchen',
    );
    final kitchen = ElementRef(kitchenIndex);
    expect(itemRotation(plan, kitchen), 0);
    final turned = rotateItem(plan, kitchen, 390);
    expect(itemRotation(turned, kitchen), 30);
    final again = FloorPlan.parse(turned.encode());
    expect((again.elements[kitchenIndex] as FixtureElement).rotation, 30);
    // Doors and outer walls don't turn.
    expect(itemRotation(plan, ElementRef(doorIndex)), isNull);
    expect(rotateItem(plan, const OutlineEdgeRef(0), 90), same(plan));
  });

  group('bar slot', () {
    final withBar = FloorPlan.parse('''
      {"id": "p", "width": 40, "height": 24,
       "tables": [
         {"id": "B1", "label": "B1", "shape": "roundedRect",
          "x": 20, "y": 12, "width": 10, "height": 2,
          "seats": {"bottom": 5}, "statusPerSeat": true, "bar": true},
         {"id": "T1", "label": "1", "shape": "rect",
          "x": 5, "y": 5, "width": 2, "height": 2}]}
    ''');

    test('0.6 × 0.4 m slots make a 5-seat bar 3 m × 0.4 m', () {
      final set = setBarSlot(withBar, widthMeters: 0.6, depthMeters: 0.4);
      final b1 = set.tableById('B1')!;
      expect(b1.width * set.metersPerUnit, closeTo(3, 1e-9));
      expect(b1.height * set.metersPerUnit, closeTo(0.4, 1e-9));
      expect(b1.seats, hasLength(5));
      expect((b1.x, b1.y), (20, 12)); // Around its center.
      // Other tables are left alone.
      expect(set.tableById('T1')!.width, 2);
    });

    test('new seat counts and new bars use the slot', () {
      final set = setBarSlot(withBar, widthMeters: 0.6, depthMeters: 0.4);
      final seven = setBarSeats(set, const TableRef('B1'), 7);
      expect(
        seven.tableById('B1')!.width * seven.metersPerUnit,
        closeTo(4.2, 1e-9),
      );
    });

    test(
      'a plan without a slot uses 0.6 × 0.4 m; saved values stay in range',
      () {
        expect((withBar.barSlotWidth, withBar.barSlotDepth), (0.6, 0.4));
        final wide = FloorPlan.parse('''
        {"id": "p", "width": 10, "height": 10,
         "barSlot": {"width": 1, "depth": 0.1}}
      ''');
        expect((wide.barSlotWidth, wide.barSlotDepth), (0.8, 0.4));
      },
    );

    test('width is kept within 0.6–0.8 m, depth within 0.4–0.6 m', () {
      final set = setBarSlot(withBar, widthMeters: 0.3, depthMeters: 2);
      expect((set.barSlotWidth, set.barSlotDepth), (0.6, 0.6));
    });

    test('saved with the plan; the default is not written', () {
      expect(withBar.toJson().containsKey('barSlot'), isFalse);
      final set = setBarSlot(withBar, widthMeters: 0.7, depthMeters: 0.5);
      final again = FloorPlan.parse(set.encode());
      expect((again.barSlotWidth, again.barSlotDepth), (0.7, 0.5));
    });
  });

  group('square and rectangle settings', () {
    final tables = FloorPlan.parse('''
      {"id": "p", "width": 40, "height": 24,
       "tables": [
         {"id": "R1", "label": "R1", "shape": "roundedRect",
          "x": 20, "y": 12, "width": 4, "height": 2,
          "seats": {"top": 4, "bottom": 4, "left": 2, "right": 2}},
         {"id": "S1", "label": "S1", "shape": "roundedRect",
          "x": 10, "y": 12, "width": 3, "height": 3,
          "seats": {"top": 1, "bottom": 1, "left": 1, "right": 1}}]}
    ''');
    double meters(double units) => units * tables.metersPerUnit;

    test('older plans: an equal-sided rounded table is a square', () {
      expect(tables.tableById('S1')!.square, isTrue);
      expect(tables.tableById('R1')!.square, isFalse);
    });

    test('rectangle: width and length follow the formula', () {
      // width 0.8, depth 0.5, buffer 0.1; 2 seats per end, 4 per long side:
      // width  = max(2 × 0.8 + 0.2, 2 × 0.5 + 0.2) = 1.8 m
      // length = 4 × 0.8 + 5 × 0.1 = 3.7 m
      final set = setRectangleSettings(
        tables,
        widthMeters: 0.8,
        depthMeters: 0.5,
        bufferMeters: 0.1,
      );
      final r1 = set.tableById('R1')!;
      expect(meters(r1.width), closeTo(3.7, 1e-9)); // Length, along x.
      expect(meters(r1.height), closeTo(1.8, 1e-9)); // Width, across.
      expect((r1.x, r1.y), (20, 12));
      // Squares are left alone.
      expect(set.tableById('S1')!.width, 3);

      // 1 seat per end: max(0.8 + 0.2, 2 × 0.5 + 0.2) = 1.2 m.
      final fewer = setRectangleSeats(set, const TableRef('R1'), ends: 1);
      expect(meters(fewer.tableById('R1')!.height), closeTo(1.2, 1e-9));
    });

    test(
      'rectangle seats: length side 2–4, width side 1–2, length > width',
      () {
        final r1 = const TableRef('R1');
        Object seats(FloorPlan p) => rectangleSeats(p.tableById('R1')!);
        expect(seats(setRectangleSeats(tables, r1, long: 9, ends: 5)), (
          long: 4,
          ends: 2,
        ));
        expect(seats(setRectangleSeats(tables, r1, long: 2, ends: 1)), (
          long: 2,
          ends: 1,
        ));
        // 2 and 2 breaks the rule: nothing changes.
        expect(setRectangleSeats(tables, r1, long: 2, ends: 2), same(tables));
        // 1 along the length is raised to 2.
        expect(seats(setRectangleSeats(tables, r1, long: 1, ends: 1)), (
          long: 2,
          ends: 1,
        ));
      },
    );

    test('square: every square table gets the width as its side', () {
      final set = setSquareSettings(tables, widthMeters: 0.75);
      final s1 = set.tableById('S1')!;
      expect((meters(s1.width), meters(s1.height)), (0.75, 0.75));
      expect(set.tableById('R1')!.width, 4); // Rectangles untouched.
    });

    test('settings are kept in range and saved', () {
      final set = setRectangleSettings(
        setSquareSettings(tables, widthMeters: 2),
        widthMeters: 0.1,
        depthMeters: 0.9,
        bufferMeters: 0.2,
      );
      expect(set.squareSeatWidth, 0.8);
      expect(
        (set.rectSeatWidth, set.rectSeatDepth, set.rectBuffer),
        (0.6, 0.6, 0.2),
      );
      final again = FloorPlan.parse(set.encode());
      expect(again.squareSeatWidth, 0.8);
      expect(
        (again.rectSeatWidth, again.rectSeatDepth, again.rectBuffer),
        (0.6, 0.6, 0.2),
      );
    });
  });

  group('circle settings', () {
    final circles = FloorPlan.parse('''
      {"id": "p", "width": 40, "height": 24,
       "tables": [
         {"id": "C4", "label": "C4", "shape": "circle",
          "x": 10, "y": 12, "width": 3, "height": 3, "seats": {"around": 4}},
         {"id": "C6", "label": "C6", "shape": "circle",
          "x": 20, "y": 12, "width": 3, "height": 3, "seats": {"around": 6}},
         {"id": "C5", "label": "C5", "shape": "circle",
          "x": 30, "y": 12, "width": 3, "height": 3, "seats": {"around": 5}}]}
    ''');
    double meters(FloorPlan p, String id) =>
        p.tableById(id)!.width * p.metersPerUnit;

    test('default radii: 45, 69, 76 and 106 cm', () {
      expect(circles.circleRadii, {4: 0.45, 6: 0.69, 8: 0.76, 10: 1.06});
      final (min, max) = FloorPlan.circleRadiusRange(6);
      expect(min, closeTo(0.64, 1e-9));
      expect(max, closeTo(0.74, 1e-9));
    });

    test('tables with 4, 6, 8 or 10 seats are twice their radius across', () {
      final set = setCircleSettings(circles, radiiMeters: {4: 0.48, 6: 0.65});
      expect(meters(set, 'C4'), closeTo(0.96, 1e-9));
      expect(meters(set, 'C6'), closeTo(1.3, 1e-9));
      expect(set.tableById('C4')!.height, set.tableById('C4')!.width);
      expect(meters(set, 'C5'), 1.5); // 5 seats: no setting, untouched.
      expect(set.circleRadii[8], 0.76); // Left out: kept.
    });

    test('circle seats: 4, 6, 8 or 10, sized from the settings', () {
      final set = setCircleSeats(circles, const TableRef('C5'), 10);
      final c5 = set.tableById('C5')!;
      expect(c5.seats, hasLength(10));
      expect(meters(set, 'C5'), closeTo(2.12, 1e-9));
      expect(c5.height, c5.width);
      expect((c5.x, c5.y), (30, 12)); // Around its center.
      // Other counts change nothing.
      expect(setCircleSeats(circles, const TableRef('C5'), 7), same(circles));
      // Rotation is offered for circles too.
      expect(itemRotation(circles, const TableRef('C4')), 0);
    });

    test('kept within 5 cm of the default radius, and saved', () {
      final set = setCircleSettings(circles, radiiMeters: {4: 0.2, 10: 1.5});
      expect(set.circleRadii[4], closeTo(0.4, 1e-9));
      expect(set.circleRadii[10], closeTo(1.11, 1e-9));
      expect(circles.toJson().containsKey('circleTable'), isFalse);
      final again = FloorPlan.parse(set.encode());
      expect(again.circleRadii[4], closeTo(0.4, 1e-9));
      expect(again.circleRadii[10], closeTo(1.11, 1e-9));
      expect(again.circleRadii[6], 0.69);
    });
  });

  group('quarter circle settings', () {
    final quarters = FloorPlan.parse('''
      {"id": "p", "width": 40, "height": 24,
       "tables": [
         {"id": "Q1", "label": "Q1", "shape": "quarterCircle",
          "corner": "bottomRight", "x": 10, "y": 12, "width": 4, "height": 4,
          "seats": {"custom": [{"x": 1, "y": 1}]}},
         {"id": "Q3", "label": "Q3", "shape": "quarterCircle",
          "corner": "topLeft", "x": 20, "y": 12, "width": 4, "height": 4,
          "seats": {"custom": [{"x": 1, "y": 1}, {"x": 2, "y": 2},
                               {"x": 3, "y": 3}]}},
         {"id": "Q4", "label": "Q4", "shape": "quarterCircle",
          "corner": "topLeft", "x": 30, "y": 12, "width": 4, "height": 4,
          "seats": {"custom": [{"x": 1, "y": 1}, {"x": 2, "y": 2},
                               {"x": 3, "y": 3}, {"x": 4, "y": 4}]}}]}
    ''');
    double meters(FloorPlan p, String id) =>
        p.tableById(id)!.width * p.metersPerUnit;

    test('default radii: 55, 62 and 68 cm, each ± 5 cm', () {
      expect(quarters.quarterCircleRadii, {1: 0.55, 2: 0.62, 3: 0.68});
      final (min, max) = FloorPlan.quarterCircleRadiusRange(2);
      expect(min, closeTo(0.57, 1e-9));
      expect(max, closeTo(0.67, 1e-9));
    });

    test(
      'tables with 1, 2 or 3 seats get their radius, seats on the curve',
      () {
        final set = setQuarterCircleSettings(
          quarters,
          radiiMeters: {1: 0.58, 3: 0.65},
        );
        expect(meters(set, 'Q1'), closeTo(0.58, 1e-9));
        expect(set.tableById('Q1')!.height, set.tableById('Q1')!.width);
        expect(meters(set, 'Q3'), closeTo(0.65, 1e-9));
        expect(meters(set, 'Q4'), 2); // 4 seats: no setting, untouched.
        expect(set.quarterCircleRadii[2], 0.62); // Left out: kept.

        // Q3's curve is top left: its circle's center is the bottom-right
        // corner, and the seats sit just past the curve at 15°, 45°, 75°
        // into it.
        final q3 = set.tableById('Q3')!;
        final center = Offset(q3.width / 2, q3.height / 2);
        for (final seat in q3.seatLayout.custom) {
          final d = seat - center;
          expect(
            d.distance,
            closeTo(
              q3.width + SeatLayout.seatGap + SeatLayout.seatSize / 2,
              1e-9,
            ),
          );
          expect(d.dx, lessThan(0));
          expect(d.dy, lessThan(0));
        }
      },
    );

    test('seat count: 1, 2 or 3, sized from the settings', () {
      final set = setQuarterCircleSeats(quarters, const TableRef('Q4'), 1);
      final q4 = set.tableById('Q4')!;
      expect(q4.seats, hasLength(1));
      expect(meters(set, 'Q4'), closeTo(0.55, 1e-9));
      expect(q4.shape.corner, QuarterCircleCorner.topLeft);
      expect(
        setQuarterCircleSeats(quarters, const TableRef('Q4'), 4),
        same(quarters),
      );
      expect(itemRotation(quarters, const TableRef('Q1')), 0);
    });

    test('kept within 5 cm of the default, and saved', () {
      final set = setQuarterCircleSettings(
        quarters,
        radiiMeters: {1: 0.1, 3: 0.9},
      );
      expect(set.quarterCircleRadii[1], closeTo(0.5, 1e-9));
      expect(set.quarterCircleRadii[3], closeTo(0.73, 1e-9));
      expect(quarters.toJson().containsKey('quarterCircleTable'), isFalse);
      final again = FloorPlan.parse(set.encode());
      expect(again.quarterCircleRadii[1], closeTo(0.5, 1e-9));
      expect(again.quarterCircleRadii[3], closeTo(0.73, 1e-9));
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
