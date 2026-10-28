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
    File('test/fixtures/main_floor.json').readAsStringSync(),
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
  final title = find.byKey(const ValueKey('selection-title'));

  // The selection bar is always there; with nothing selected its buttons
  // are disabled and the name is blank.
  void expectNothingSelected(WidgetTester tester) {
    for (final key in ['move', 'edit', 'save-item']) {
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(ValueKey(key)),
      );
      expect(button.onPressed, isNull, reason: '$key disabled');
    }
    expect(tester.widget<Text>(title).data, isEmpty);
  }

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
    expectNothingSelected(tester);

    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();

    expect(moveButton, findsOneWidget);
    expect(editButton, findsOneWidget);
    expect(find.byKey(const ValueKey('save-item')), findsOneWidget);
    expect(find.text('1 · Table · roundedRect'), findsOneWidget);

    // Tapping empty floor clears the selection.
    await tester.tapAt(floorPoint(tester, const Offset(20, 21)));
    await tester.pumpAndSettle();
    expectNothingSelected(tester);
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
    expectNothingSelected(tester);

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

  testWidgets('the selection bar sits above the ruler: name left, buttons '
      'right', (tester) async {
    await openPage(tester);
    final ruler = tester.getRect(find.byKey(const ValueKey('ruler-top')));
    final save = tester.getRect(find.byKey(const ValueKey('save-item')));
    expect(save.bottom, lessThanOrEqualTo(ruler.top));

    // Selecting the entrance door fills in the name; the bar doesn't move.
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('ruler-top'))), ruler);
    final name = tester.getRect(find.text('Entrance · Door · 1.5 m'));
    final move = tester.getRect(moveButton);
    expect(name.right, lessThanOrEqualTo(move.left));
    expect(name.top, lessThan(ruler.top));
    expect(tester.widget<ButtonStyleButton>(moveButton).onPressed, isNotNull);
  });

  testWidgets('step 1 selects doors', (tester) async {
    await openPage(tester);

    // The entrance door is centered at (20, 24).
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    expect(find.text('Entrance · Door · 1.5 m'), findsOneWidget);
  });

  testWidgets('tapping a wall shows its start and end', (tester) async {
    await openPage(tester);

    // The inner kitchen wall.
    await tester.tapAt(floorPoint(tester, const Offset(30, 5)));
    await tester.pumpAndSettle();
    expect(find.text('Wall · (30, 0) → (40, 10)'), findsOneWidget);

    // An outer wall: selectable and movable, but has no name to edit.
    await tester.tapAt(floorPoint(tester, const Offset(10, 23.9)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Outer wall · '), findsOneWidget);
    final edit = tester.widget<ButtonStyleButton>(editButton);
    expect(edit.onPressed, isNull);
    expect(moveButton, findsOneWidget);
  });

  testWidgets('Move on a wall drags its start or end point', (tester) async {
    await openPage(tester);

    Future<void> drag(Offset from, Offset to) async {
      final start = floorPoint(tester, from);
      final step = (floorPoint(tester, to) - start) / 10;
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    // Select the bottom outer wall, (40, 24) → (0, 24), and turn on Move.
    // (Its ends are clear of the toolbar at the top right.)
    await tester.tapAt(floorPoint(tester, const Offset(10, 23.9)));
    await tester.pumpAndSettle();
    expect(find.text('Outer wall · (40, 24) → (0, 24)'), findsOneWidget);
    await tester.tap(moveButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('Drag the Start or End point'), findsOneWidget);

    // Drag the end point 2 units right: only that end moves. The drags start
    // a little inside the floor (the ends sit on its edge); anywhere within
    // a fingertip of an end grabs it, and the end snaps on release.
    await drag(const Offset(0.3, 23.7), const Offset(2.3, 23.7));
    expect(find.text('Outer wall · (40, 24) → (2, 24)'), findsOneWidget);

    // Drag the start point 1 unit up.
    await drag(const Offset(39.7, 23.7), const Offset(39.7, 22.7));
    expect(find.text('Outer wall · (40, 23) → (2, 24)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    final outline = repository.saved!.floorOutline;
    expect(outline, contains(const Offset(40, 23)));
    expect(outline, contains(const Offset(2, 24)));
    expect(outline, isNot(contains(const Offset(0, 24))));
  });

  testWidgets('review mode: items cannot be selected', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'review');

    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();
    expectNothingSelected(tester);
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

  testWidgets('Remove in the Edit panel removes the item, with Undo', (
    tester,
  ) async {
    final removeButton = find.byKey(const ValueKey('remove-item'));
    final table1 = find.byKey(const ValueKey('table-T1'));
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');

    await tester.tap(table1);
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    // Gone from the floor; the selection and side bar close.
    expect(table1, findsNothing);
    expect(removeButton, findsNothing);
    expectNothingSelected(tester);
    expect(find.text('Removed 1'), findsOneWidget);

    // Undo brings it back, selected again.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(table1, findsOneWidget);
    expect(moveButton, findsOneWidget);

    // Remove again and save: the saved plan has no table 1.
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(repository.saved!.tableById('T1'), isNull);
    expect(repository.saved!.tables, hasLength(plan.tables.length - 1));
  });

  testWidgets('Remove works for room items too', (tester) async {
    await openPage(tester);
    final before = plan.elements.whereType<DoorElement>().length;

    // The entrance door.
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-item')));
    await tester.pumpAndSettle();
    expect(find.text('Removed Entrance'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(
      repository.saved!.elements.whereType<DoorElement>(),
      hasLength(before - 1),
    );
  });

  testWidgets('Edit sets a door\'s length in meters', (tester) async {
    final length = find.byKey(const ValueKey('item-length'));
    await openPage(tester);

    // The entrance door: 3 units = 1.5 m.
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(length).controller!.text, '1.5');

    // + twice: 1.7 m. The toolbar shows the new length right away.
    await tester.tap(find.byKey(const ValueKey('length-plus')));
    await tester.tap(find.byKey(const ValueKey('length-plus')));
    await tester.pumpAndSettle();
    expect(find.text('Entrance · Door · 1.7 m'), findsOneWidget);

    // Typing works too, and a bad value is refused with a message.
    await tester.enterText(length, 'abc');
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a length'), findsOneWidget);
    expect(find.text('Entrance · Door · 1.7 m'), findsOneWidget);
    await tester.enterText(length, '2,25');
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a length'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    final door = repository.saved!.elements.whereType<DoorElement>().first;
    expect(door.width, 4.5); // 2.25 m / 0.5 m per unit
  });

  testWidgets('tables have no length field', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('item-length')), findsNothing);
  });

  testWidgets('Edit sets a fixture\'s width and height in meters', (
    tester,
  ) async {
    final width = find.byKey(const ValueKey('item-width'));
    final height = find.byKey(const ValueKey('item-height'));
    String text(Finder f) => tester.widget<TextField>(f).controller!.text;
    await openPage(tester);

    // The kitchen: 9.6 × 9.6 units = 4.8 × 4.8 m, centered at (35, 5).
    await tester.tapAt(floorPoint(tester, const Offset(35, 5)));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen · Fixture · 4.8 × 4.8 m'), findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(text(width), '4.8');
    expect(text(height), '4.8');
    expect(find.byKey(const ValueKey('item-length')), findsNothing);
    expect(find.byKey(const ValueKey('item-diameter')), findsNothing);

    await tester.enterText(width, '3');
    await tester.tap(find.byKey(const ValueKey('height-minus')));
    await tester.pumpAndSettle();
    expect(text(height), '4.7');
    expect(find.text('Kitchen · Fixture · 3 × 4.7 m'), findsWidgets);

    // Out of range: shows an error and keeps the last good size.
    await tester.enterText(width, '0.1');
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a width from'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    final kitchen = repository.saved!.elements
        .whereType<FixtureElement>()
        .firstWhere((f) => f.label == 'Kitchen');
    expect(kitchen.width, 6); // 3 m
    expect(kitchen.height, closeTo(9.4, 1e-9)); // 4.7 m
    expect((kitchen.x, kitchen.y), (35, 5)); // Same center.
  });

  testWidgets('Edit sets a plant\'s diameter', (tester) async {
    final diameter = find.byKey(const ValueKey('item-diameter'));
    await openPage(tester);

    // A plant: 1.6 units = 0.8 m across, centered at (15.2, 13.2).
    await tester.tapAt(floorPoint(tester, const Offset(15.2, 13.2)));
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-width')), findsNothing);
    expect(tester.widget<TextField>(diameter).controller!.text, '0.8');

    await tester.tap(find.byKey(const ValueKey('diameter-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    final plant = repository.saved!.elements
        .whereType<FixtureElement>()
        .firstWhere((f) => (f.x, f.y) == (15.2, 13.2));
    // 0.9 m = 1.8 units, and still round.
    expect(plant.width, closeTo(1.8, 1e-9));
    expect(plant.height, closeTo(1.8, 1e-9));
  });

  testWidgets('Edit picks the wall a door sits on', (tester) async {
    await openPage(tester);
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    // Currently on the bottom outer wall.
    expect(find.text('Outer wall 5 · (40, 24) → (0, 24)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('item-wall')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outer wall 4 · (40, 0) → (40, 24)').last);
    await tester.pumpAndSettle();
    expect(find.text('Outer wall 4 · (40, 0) → (40, 24)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    final door = repository.saved!.elements.whereType<DoorElement>().firstWhere(
      (d) => d.label == 'Entrance',
    );
    // On the right wall, as close to where it was as fits, turned upright.
    expect((door.x, door.y, door.angle), (40.0, 22.5, 90.0));
  });

  testWidgets('Move slides a door onto the nearest wall', (tester) async {
    await openPage(tester);
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    await tester.tap(moveButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('sticks to the'), findsOneWidget);

    // Drag from the door toward the left outer wall (x = 0).
    final start = floorPoint(tester, const Offset(20, 23.5));
    final step = (floorPoint(tester, const Offset(1, 18)) - start) / 20;
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(step);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    final door = repository.saved!.elements.whereType<DoorElement>().firstWhere(
      (d) => d.label == 'Entrance',
    );
    expect(door.x, 0);
    expect(door.angle, 90);
    // The door moves as far as the finger did, from its own center
    // (20, 24): (20, 24) + (-19, -5.5) = (1, 18.5), stuck to x = 0.
    expect(door.y, closeTo(18.5, 0.11));
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
    // Move turns into Done (a check mark).
    expect(
      find.descendant(of: moveButton, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

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
