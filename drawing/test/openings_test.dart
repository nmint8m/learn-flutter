import 'dart:io';

import 'package:drawing/floor_plan/editor/floor_edits.dart';
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The L-shaped test room: outline (0,12) (26,12) (26,0) (40,0) (40,24)
  // (0,24), plus the kitchen wall (30,0) → (30,10) → (40,10).
  final plan = FloorPlan.parse(
    File('test/fixtures/main_floor.json').readAsStringSync(),
  );
  final entrance = plan.elements.indexWhere(
    (e) => e is DoorElement && e.label == 'Entrance',
  );
  OpeningElement opening(FloorPlan p, int i) => p.elements[i] as OpeningElement;

  test('lists every straight wall: outer walls, then inner wall parts', () {
    final walls = wallSegments(plan);
    expect(walls, hasLength(6 + 2));
    expect(walls.first.name, 'Outer wall 1 · (0, 12) → (26, 12)');
    expect(walls[4].name, 'Outer wall 5 · (40, 24) → (0, 24)');
    expect(walls[6].name, 'Wall (part 1) · (30, 0) → (30, 10)');
  });

  test('a door is on the nearest wall and lies along it', () {
    expect(openingWall(plan, entrance)!.name, startsWith('Outer wall 5'));

    // Put it near the right outer wall (x = 40, top to bottom).
    final moved = placeOpening(plan, entrance, const Offset(38, 6));
    final door = opening(moved, entrance);
    expect((door.x, door.y, door.angle), (40.0, 6.0, 90.0));
  });

  test('a door is kept fully on its wall', () {
    // Near the bottom-right corner (closer to the bottom wall): the 3-unit
    // door stops 1.5 from the end.
    final door = opening(
      placeOpening(plan, entrance, const Offset(39.5, 23.9)),
      entrance,
    );
    expect(door.y, 24);
    expect(door.x, closeTo(38.5, 1e-9));
  });

  test('on a slanted wall, a door turns to match it', () {
    final slanted = FloorPlan.parse('''
      {"id": "p", "width": 10, "height": 10,
       "outline": [[0, 0], [10, 10], [0, 10]],
       "elements": [{"type": "window", "x": 6, "y": 4, "width": 2}]}
    ''');
    final window = opening(stickOpenings(slanted), 0);
    expect(window.angle, closeTo(45, 1e-9));
    expect(window.x, closeTo(5, 1e-9));
    expect(window.y, closeTo(5, 1e-9));
    // Saved with its angle, and read back the same.
    final reread = FloorPlan.parse(stickOpenings(slanted).encode());
    expect(opening(reread, 0).angle, closeTo(45, 1e-9));
  });

  test('a door off any wall is moved onto the nearest one', () {
    final standalone = FloorPlan.parse('''
      {"id": "p", "width": 10, "height": 10,
       "elements": [{"type": "door", "x": 5, "y": 8.5, "width": 2}]}
    ''');
    final door = opening(stickOpenings(standalone), 0);
    expect((door.x, door.y, door.angle), (5.0, 10.0, 0.0));
  });

  test('a door follows its wall when the wall moves', () {
    // The entrance is on outer wall 5 (index 4), along y = 24.
    final moved = stickOpenings(
      moveItem(plan, const OutlineEdgeRef(4), const Offset(0, -1)),
    );
    expect(opening(moved, entrance).y, 23);
  });

  test('when its wall is removed, a door moves to the nearest other wall', () {
    final kitchenDoor = plan.elements.indexWhere(
      (e) => e is DoorElement && e.label == null,
    );
    expect(openingWall(plan, kitchenDoor)!.name, startsWith('Wall'));

    final kitchenWall = plan.elements.indexWhere((e) => e is WallElement);
    final removed = stickOpenings(removeItem(plan, ElementRef(kitchenWall)));
    // Removing the wall (listed first) shifts the door up one place.
    final door = opening(removed, kitchenDoor - 1);
    expect(openingWall(removed, kitchenDoor - 1)!.name, startsWith('Outer'));
    expect(door.angle, anyOf(0.0, 90.0));
  });

  test('vertical doors keep the readable "orientation" in the file', () {
    final moved = placeOpening(plan, entrance, const Offset(38, 6));
    final json = moved.toJson();
    final door = (json['elements']! as List)[entrance] as Map;
    expect(door['orientation'], 'vertical');
    expect(door.containsKey('angle'), isFalse);
  });
}
