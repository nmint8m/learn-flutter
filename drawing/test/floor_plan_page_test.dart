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
    for (final key in [
      'move',
      'edit',
      'duplicate',
      'save-item',
      'remove-item',
    ]) {
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

  testWidgets('step 1 hides tables; rulers show in every step', (tester) async {
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
    expect(topRuler, findsOneWidget);
    expect(leftRuler, findsOneWidget);

    await goToStep(tester, 'review');
    expect(find.byKey(const ValueKey('table-T1')), findsOneWidget);
    expect(topRuler, findsOneWidget);
    expect(leftRuler, findsOneWidget);
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

  testWidgets('bottom bar: hint on the left, zoom buttons on the right', (
    tester,
  ) async {
    final zoomIn = find.byKey(const ValueKey('zoom-in'));
    final zoomOut = find.byKey(const ValueKey('zoom-out'));
    String level() =>
        tester.widget<Text>(find.byKey(const ValueKey('zoom-level'))).data!;
    bool enabled(Finder f) => tester.widget<IconButton>(f).onPressed != null;
    Rect floor() => tester.getRect(find.byType(DragTarget<PaletteItem>));
    await openPage(tester);

    final hint = tester.getRect(find.byKey(const ValueKey('hint')));
    expect(hint.right, lessThanOrEqualTo(tester.getRect(zoomOut).left));
    expect(hint.top, greaterThan(floor().bottom));

    // The floor starts at 100%: fitted to the view.
    expect(level(), '100%');
    final before = floor();

    // Zoom in: bigger, around the middle of the view.
    await tester.tap(zoomIn);
    await tester.pumpAndSettle();
    expect(level(), '150%');
    expect(floor().width, closeTo(before.width * 1.5, 0.01));
    expect(floor().center.dx, closeTo(before.center.dx, 0.01));

    // Up to 600% at most.
    final up = <String>[];
    for (var i = 0; i < 10 && enabled(zoomIn); i++) {
      await tester.tap(zoomIn);
      await tester.pumpAndSettle();
      up.add(level());
    }
    expect(up, ['200%', '300%', '400%', '600%']);

    // Down to 25% at least: smaller than the view, still centered.
    final down = <String>[];
    for (var i = 0; i < 10 && enabled(zoomOut); i++) {
      await tester.tap(zoomOut);
      await tester.pumpAndSettle();
      down.add(level());
    }
    expect(down, ['400%', '300%', '200%', '150%', '100%', '75%', '50%', '25%']);
    expect(floor().width, closeTo(before.width / 4, 0.01));
    expect(floor().center.dx, closeTo(before.center.dx, 0.01));
    expect(floor().center.dy, closeTo(before.center.dy, 0.01));

    // And back to 100%: the floor fits the view again.
    for (var i = 0; i < 3; i++) {
      await tester.tap(zoomIn);
      await tester.pumpAndSettle();
    }
    expect(level(), '100%');
    expect(floor().width, closeTo(before.width, 0.01));
  });

  testWidgets('Review shows the whole floor', (tester) async {
    String level() =>
        tester.widget<Text>(find.byKey(const ValueKey('zoom-level'))).data!;
    Rect view() => tester.getRect(find.byType(InteractiveViewer));
    bool allTablesShown() =>
        [for (final t in plan.tables) find.byKey(ValueKey('table-${t.id}'))]
            .every((table) => view().contains(tester.getRect(table).center));
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');

    await tester.tap(find.byKey(const ValueKey('zoom-in')));
    await tester.tap(find.byKey(const ValueKey('zoom-in')));
    await tester.pumpAndSettle();
    expect(level(), '200%');
    expect(allTablesShown(), isFalse);

    await goToStep(tester, 'review');
    expect(level(), '100%');
    expect(allTablesShown(), isTrue);
  });

  testWidgets('Review zooms out to show tables past the room', (tester) async {
    // Table T1 sits 6 units right of the room's right wall.
    repository = _MemoryRepository(
      FloorPlan.parse('''
        {"id": "p", "width": 40, "height": 24,
         "tables": [{"id": "T1", "label": "1", "shape": "rect",
                     "x": 46, "y": 12, "width": 2, "height": 2}]}
      '''),
    );
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await goToStep(tester, 'tableAndSeat');
    final view = tester.getRect(find.byType(InteractiveViewer));
    final table = find.byKey(const ValueKey('table-T1'));
    expect(view.contains(tester.getRect(table).center), isFalse);

    await goToStep(tester, 'review');
    final level = tester
        .widget<Text>(find.byKey(const ValueKey('zoom-level')))
        .data!;
    expect(level, isNot('100%'));
    final reviewView = tester.getRect(find.byType(InteractiveViewer));
    expect(reviewView.contains(tester.getRect(table).topRight), isTrue);
  });

  testWidgets('100% fits the whole room, walls past the floor included', (
    tester,
  ) async {
    repository = _MemoryRepository(
      FloorPlan.parse('''
        {"id": "p", "width": 40, "height": 24,
         "outline": [[0, 0], [47, 0], [47, 24], [0, 24]]}
      '''),
    );
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    final view = tester.getRect(find.byType(InteractiveViewer));
    final room = tester.getRect(find.byType(DragTarget<PaletteItem>));
    expect(room.width / room.height, closeTo(47 / 24, 0.01));
    expect(view.left, lessThanOrEqualTo(room.left));
    expect(room.right, lessThanOrEqualTo(view.right + 0.01));
  });

  testWidgets('walls and windows past the floor\'s width can be tapped', (
    tester,
  ) async {
    // Like the saved room: the right wall at x = 47, past the 40-unit width,
    // with a window on it.
    repository = _MemoryRepository(
      FloorPlan.parse('''
        {"id": "p", "width": 40, "height": 24,
         "outline": [[0, 0], [47, 0], [47, 24], [0, 24]],
         "elements": [{"type": "window", "x": 47, "y": 6, "width": 3,
                       "angle": 90}]}
      '''),
    );
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    // The room box now spans x 0..47.
    Offset at(Offset units) {
      final room = tester.getRect(find.byType(DragTarget<PaletteItem>));
      return room.topLeft + units * (room.width / 47);
    }

    await tester.tapAt(at(const Offset(46.9, 6)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Window · 1.5 m'), findsWidgets);

    await tester.tapAt(at(const Offset(46.9, 18)));
    await tester.pumpAndSettle();
    expect(find.text('Outer wall · (47, 0) → (47, 24)'), findsOneWidget);
  });

  testWidgets('zoom buttons are frozen in Move mode', (tester) async {
    await openPage(tester);
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    await tester.tap(moveButton);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('zoom-in')))
          .onPressed,
      isNull,
    );
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

  testWidgets('Remove asks first, then removes the item, with Undo', (
    tester,
  ) async {
    final removeButton = find.byKey(const ValueKey('remove-item'));
    final question = find.text('Remove item?');
    final confirm = find.byKey(const ValueKey('confirm-remove'));
    final cancel = find.byKey(const ValueKey('cancel-remove'));
    final table1 = find.byKey(const ValueKey('table-T1'));
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');

    await tester.tap(table1);
    await tester.pumpAndSettle();
    // The Edit panel no longer has a Remove button.
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
    expect(removeButton, findsOneWidget); // Only the one in the bar.

    // Remove → the question; ✕ keeps the table.
    expect(question, findsNothing);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(question, findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(question, findsNothing);
    expect(table1, findsOneWidget);

    // Remove → ✓ removes it; the selection and side bar close.
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(table1, findsNothing);
    expect(question, findsNothing);
    expect(find.byKey(const ValueKey('item-name')), findsNothing);
    expectNothingSelected(tester);
    expect(find.text('Removed 1'), findsOneWidget);

    // Undo brings it back, selected again.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(table1, findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(removeButton).onPressed, isNotNull);

    // Remove again and save: the saved plan has no table 1.
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(repository.saved!.tableById('T1'), isNull);
    expect(repository.saved!.tables, hasLength(plan.tables.length - 1));
  });

  testWidgets('the Remove question floats under the button; the floor '
      'stays put', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();
    Rect floor() => tester.getRect(find.byType(DragTarget<PaletteItem>));
    final before = floor();

    final remove = find.byKey(const ValueKey('remove-item'));
    await tester.tap(remove);
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byKey(const ValueKey('remove-question')));
    final button = tester.getRect(remove);
    expect(card.top, greaterThanOrEqualTo(button.bottom));
    expect(card.right, closeTo(button.right, 0.5));
    expect(floor(), before);
  });

  testWidgets('the Remove question closes when another item is selected', (
    tester,
  ) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-item')));
    await tester.pumpAndSettle();
    expect(find.text('Remove item?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('table-T2')));
    await tester.pumpAndSettle();
    expect(find.text('Remove item?'), findsNothing);

    // And back on table 1: still closed.
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();
    expect(find.text('Remove item?'), findsNothing);
  });

  testWidgets('Remove works for room items too', (tester) async {
    await openPage(tester);
    final before = plan.elements.whereType<DoorElement>().length;

    // The entrance door.
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Removed Entrance'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(
      repository.saved!.elements.whereType<DoorElement>(),
      hasLength(before - 1),
    );
  });

  testWidgets('Duplicate copies a table 0.2 m right and down', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('duplicate')));
    await tester.pumpAndSettle();
    // The copy is the next table, and it's selected.
    expect(find.byKey(const ValueKey('table-T8')), findsOneWidget);
    expect(find.text('Duplicated 1'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('selection-title'))).data,
      '8 · Table · roundedRect',
    );

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    final original = repository.saved!.tableById('T1')!;
    final copy = repository.saved!.tableById('T8')!;
    // 0.2 m = 0.4 units at 0.5 m per unit.
    expect(copy.x, closeTo(original.x + 0.4, 1e-9));
    expect(copy.y, closeTo(original.y + 0.4, 1e-9));
    expect(
      (copy.width, copy.height, copy.shape.shape),
      (original.width, original.height, original.shape.shape),
    );
    expect(copy.seats, hasLength(original.seats.length));
  });

  testWidgets('outer walls can\'t be duplicated or removed', (tester) async {
    await openPage(tester);
    await tester.tapAt(floorPoint(tester, const Offset(10, 23.9)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Outer wall · '), findsOneWidget);
    for (final key in ['duplicate', 'remove-item']) {
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).onPressed,
        isNull,
        reason: key,
      );
    }
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
