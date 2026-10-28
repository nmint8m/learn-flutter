import 'dart:math' as math;

import 'package:drawing/floor_plan/editor/floor_edits.dart';
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:drawing/floor_plan/floor_plan_page.dart';
import 'package:drawing/floor_plan/floor_plan_store.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepository implements FloorPlanRepository {
  _MemoryRepository(this.plan);

  final FloorPlan plan;
  FloorPlan? saved;

  @override
  Future<FloorPlan> load() async => plan;

  @override
  Future<String> save(FloorPlan plan) async {
    saved = plan;
    return 'memory';
  }
}

/// Lets the frame settle. A single tap on the floor only counts once the
/// double-tap window has passed, so that's waited out first.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
  await tester.pumpAndSettle();
}

void main() {
  // The room shape from assets/floor_plans/main_floor.json, with its slanted
  // outer wall from (20.5, 5.5) to (26, 0).
  final plan = FloorPlan.parse('''
    {"id": "main-floor", "name": "Main floor", "width": 40, "height": 24,
     "metersPerUnit": 0.5,
     "outline": [[0, 5.5], [20.5, 5.5], [26, 0], [40, 0], [40, 24], [0, 24]]}
  ''');
  const wallStart = Offset(20.5, 5.5);
  const wallEnd = Offset(26, 0);

  testWidgets('add a 2 m window on the wall (20.5, 5.5) → (26, 0)', (
    tester,
  ) async {
    final repository = _MemoryRepository(plan);
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: repository)),
    );
    await settle(tester);

    // 1. Step 1 (Room & Decor): tap Window in the panel. It's added to the
    //    middle of the floor, stuck to the nearest wall, and selected.
    await tester.tap(find.byKey(const ValueKey('palette-window')));
    await settle(tester);
    expect(find.text('Added Window'), findsOneWidget);

    // 2. Edit → Wall: pick the slanted wall.
    await tester.tap(find.byKey(const ValueKey('edit')));
    await settle(tester);
    const wallName = 'Outer wall 2 · (20.5, 5.5) → (26, 0)';
    await tester.tap(find.byKey(const ValueKey('item-wall')));
    await settle(tester);
    await tester.tap(find.text(wallName).last);
    await settle(tester);
    expect(find.text(wallName), findsOneWidget);

    // 3. Length: 2 m.
    await tester.enterText(find.byKey(const ValueKey('item-length')), '2');
    await settle(tester);
    expect(find.text('Window · 2 m'), findsWidgets);

    // 4. Save, and check what was saved.
    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final saved = repository.saved!;
    final window = saved.elements.single as WindowElement;

    // 2 m at 0.5 m per unit = 4 units long.
    expect(window.width, 4);
    expect(itemLengthMeters(saved, const ElementRef(0)), 2);

    // It lies along the wall: the wall runs up and to the right at 45°,
    // which is 135° in screen terms (y grows downward).
    expect(window.angle, closeTo(135, 1e-9));

    // Both ends are on the wall, between its start and end.
    final wall = wallSegments(saved)[1];
    expect((wall.start, wall.end), (wallStart, wallEnd));
    final (a, b) = window.ends;
    for (final end in [a, b]) {
      expect(wall.distanceTo(end), lessThan(1e-9), reason: '$end on wall');
      final along = wall.distanceAlong(end);
      expect(along, inInclusiveRange(0, wall.length));
    }
    // The wall is 5.5·√2 ≈ 7.78 units long, so 4 units fit with room
    // to spare.
    expect(wall.length, closeTo(5.5 * math.sqrt2, 1e-9));
    expect((b - a).distance, closeTo(4, 1e-9));

    // And it reads back the same from the saved JSON.
    final reread = FloorPlan.parse(saved.encode());
    final rereadWindow = reread.elements.single as WindowElement;
    expect(rereadWindow.angle, closeTo(135, 1e-9));
    expect(
      wallSegments(reread)[1].distanceTo(rereadWindow.center),
      lessThan(0.08),
    );
  });
}
