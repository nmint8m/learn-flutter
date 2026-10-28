import 'dart:io';

import 'package:drawing/floor_plan/editor/floor_edits.dart';
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plan = FloorPlan.parse(
    File('assets/floor_plans/main_floor.json').readAsStringSync(),
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

  test('moveItem and snapItem move a table to half a unit', () {
    const ref = TableRef('T1');
    final moved = snapItem(
      moveItem(plan, ref, const Offset(2.2, -0.9)),
      ref,
    ).tableById('T1')!;
    expect((moved.x, moved.y), (t1.x + 2, t1.y - 1));
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

  test('renameItem changes the name', () {
    final renamed = renameItem(plan, ElementRef(doorIndex), 'Front door');
    expect(itemName(renamed, ElementRef(doorIndex)), 'Front door');
    expect(itemKind(renamed, ElementRef(doorIndex)), 'Door');
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
