import 'dart:io';

import 'package:drawing/floor_plan/editor/palette.dart';
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:drawing/floor_plan/floor_plan_page.dart';
import 'package:drawing/floor_plan/floor_plan_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps the plan in memory instead of a file.
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

void main() {
  // Read the real sample plan once, and hand it to the page directly: loading
  // assets inside widget tests doesn't reliably finish.
  final plan = FloorPlan.parse(
    File('assets/floor_plans/main_floor.json').readAsStringSync(),
  );
  late _MemoryRepository repository;

  setUp(() => repository = _MemoryRepository(plan));

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goToStep(WidgetTester tester, String step) async {
    await tester.tap(find.byKey(ValueKey('step-$step')));
    await tester.pumpAndSettle();
  }

  /// Screen position of a point given in floor units.
  Offset floorPoint(WidgetTester tester, Offset units) {
    final floor = tester.getRect(find.byType(DragTarget<PaletteItem>));
    return floor.topLeft + units * (floor.width / plan.width);
  }

  Finder palette(String item) => find.byKey(ValueKey('palette-$item'));
  final moveButton = find.byKey(const ValueKey('move'));
  final editButton = find.byKey(const ValueKey('edit'));

  testWidgets('each step shows its own panel items', (tester) async {
    await openPage(tester);

    // Step 1: room & decor.
    // The step bar and the panel heading.
    expect(find.text('Room & Decor'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('save')), findsOneWidget);
    expect(palette('wall'), findsOneWidget);
    expect(palette('window'), findsOneWidget);
    expect(palette('circleTable'), findsNothing);

    // Step 2: tables.
    await goToStep(tester, 'tableAndSeat');
    expect(palette('wall'), findsNothing);
    expect(palette('roundedRectTable'), findsOneWidget);
    expect(palette('quarterCircleTable'), findsOneWidget);

    // Step 3: no panel.
    await goToStep(tester, 'review');
    expect(palette('wall'), findsNothing);
    expect(palette('circleTable'), findsNothing);
  });

  testWidgets('the table state legend is gone', (tester) async {
    await openPage(tester);
    expect(find.textContaining('Occupied'), findsNothing);
    expect(find.textContaining('Needs bill'), findsNothing);
  });

  testWidgets('step 2: tapping a table shows Move, Edit and Save', (
    tester,
  ) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    expect(moveButton, findsNothing);

    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();

    expect(moveButton, findsOneWidget);
    expect(editButton, findsOneWidget);
    expect(find.byKey(const ValueKey('save-item')), findsOneWidget);
    expect(find.text('1 · Table · roundedRect'), findsOneWidget);

    // Tapping empty floor clears the selection.
    await tester.tapAt(floorPoint(tester, const Offset(20, 21)));
    await tester.pumpAndSettle();
    expect(moveButton, findsNothing);
  });

  testWidgets('step 1 hides tables and shows rulers; step 2 the reverse', (
    tester,
  ) async {
    final topRuler = find.byKey(const ValueKey('ruler-top'));
    final leftRuler = find.byKey(const ValueKey('ruler-left'));
    await openPage(tester);

    expect(find.byKey(const ValueKey('table-T1')), findsNothing);
    expect(topRuler, findsOneWidget);
    expect(leftRuler, findsOneWidget);
    // Room items are still drawn.
    expect(find.text('Kitchen'), findsOneWidget);

    // Tapping where table 1 is selects nothing.
    final t1 = plan.tableById('T1')!;
    await tester.tapAt(floorPoint(tester, Offset(t1.x, t1.y)));
    await tester.pumpAndSettle();
    expect(moveButton, findsNothing);

    await goToStep(tester, 'tableAndSeat');
    expect(find.byKey(const ValueKey('table-T1')), findsOneWidget);
    expect(topRuler, findsNothing);
    expect(leftRuler, findsNothing);

    await goToStep(tester, 'review');
    expect(find.byKey(const ValueKey('table-T1')), findsOneWidget);
    expect(topRuler, findsNothing);
  });

  testWidgets('the rulers sit beside the floor, not on it', (tester) async {
    await openPage(tester);
    final floor = tester.getRect(find.byType(DragTarget<PaletteItem>));
    final top = tester.getRect(find.byKey(const ValueKey('ruler-top')));
    final left = tester.getRect(find.byKey(const ValueKey('ruler-left')));

    expect(top.bottom, lessThanOrEqualTo(floor.top));
    expect(left.right, lessThanOrEqualTo(floor.left));
    expect(top.left, left.right);
  });

  testWidgets('step 1 selects doors', (tester) async {
    await openPage(tester);

    // The entrance door is centered at (20, 24).
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    expect(find.text('Entrance · Door'), findsOneWidget);
  });

  testWidgets('review mode: items cannot be selected', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'review');

    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();
    expect(moveButton, findsNothing);
  });

  testWidgets('Edit renames the item, Save writes it', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();

    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('item-name')), 'Window');
    await tester.pumpAndSettle();
    // The new name shows on the floor right away.
    expect(find.text('Window'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(repository.saved!.tableById('T1')!.label, 'Window');
    expect(find.text('Saved to memory'), findsOneWidget);
  });

  testWidgets('Move drags the selected item without panning the floor', (
    tester,
  ) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    final before = plan.tableById('T1')!;

    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();
    await tester.tap(moveButton);
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);

    // Drag 3 floor units to the right, starting on empty floor, in small
    // steps like a real finger.
    final start = floorPoint(tester, const Offset(20, 21));
    final step = (floorPoint(tester, const Offset(23, 21)) - start) / 10;
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(step);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    final after = repository.saved!.tableById('T1')!;
    expect(after.x - before.x, closeTo(3, 0.01));
    expect(after.y, before.y);
  });

  testWidgets('tapping a panel item adds and selects it', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');

    await tester.tap(palette('circleTable'));
    await tester.pumpAndSettle();

    expect(find.text('Added Table 8'), findsOneWidget);
    expect(find.byKey(const ValueKey('table-T8')), findsOneWidget);
    expect(moveButton, findsOneWidget);
  });

  testWidgets('dragging a panel item onto the floor adds it', (tester) async {
    await openPage(tester);

    final tile = tester.getCenter(palette('plant'));
    final target = floorPoint(tester, const Offset(20, 20));

    // Sideways first: the panel only starts a drag on a horizontal move.
    final gesture = await tester.startGesture(tile);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Added Plant'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    final plant = repository.saved!.elements.last as FixtureElement;
    expect((plant.x, plant.y), (20.0, 20.0));
  });

  testWidgets('shows a readable error for a broken plan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: _BrokenRepository())),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not load the floor plan'),
      findsOneWidget,
    );
    expect(find.textContaining('"shape" must be'), findsOneWidget);
  });
}

class _BrokenRepository implements FloorPlanRepository {
  @override
  Future<FloorPlan> load() async =>
      throw const FormatException('table "T9": "shape" must be one of ...');

  @override
  Future<String> save(FloorPlan plan) async => throw UnimplementedError();
}
