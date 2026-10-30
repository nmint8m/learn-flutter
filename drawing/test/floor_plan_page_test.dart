import 'dart:io';

import 'package:drawing/floor_plan/editor/floor_edits.dart'
    show rectangleSeats, tableInsideRoom;
import 'package:drawing/floor_plan/editor/palette.dart';
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:drawing/floor_plan/floor_plan_page.dart';
import 'package:drawing/floor_plan/floor_plan_store.dart';
import 'package:drawing/floor_plan/floor_plan_view.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
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

/// Lets the frame settle. A single tap on the floor only counts once the
/// double-tap window has passed, so that's waited out first.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
  await tester.pumpAndSettle();
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
    await settle(tester);
  }

  Future<void> goToStep(WidgetTester tester, String step) async {
    await tester.tap(find.byKey(ValueKey('step-$step')));
    await settle(tester);
  }

  /// Screen position of a point given in floor units.
  Offset floorPoint(WidgetTester tester, Offset units) {
    final floor = tester.getRect(find.byType(DragTarget<PaletteItem>));
    return floor.topLeft + units * (floor.width / plan.width);
  }

  // Tall enough for the whole Edit panel (seats, counts and rotation).
  Future<void> openTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openPage(tester);
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
    expect(find.text('Room & decor'), findsOneWidget);
    expect(find.text('Room & Decor'), findsOneWidget);
    expect(find.byKey(const ValueKey('save')), findsOneWidget);
    expect(palette('wall'), findsOneWidget);
    expect(palette('window'), findsOneWidget);
    expect(palette('circleTable'), findsNothing);

    // Step 2: tables.
    await goToStep(tester, 'tableAndSeat');
    expect(palette('wall'), findsNothing);
    expect(palette('roundedRectTable'), findsOneWidget);
    expect(palette('quarterCircleTable'), findsOneWidget);
    expect(palette('semicircleTable'), findsNothing);

    // Steps 3 and 4: no panel.
    await goToStep(tester, 'tableConfiguration');
    expect(palette('wall'), findsNothing);
    expect(palette('circleTable'), findsNothing);
    await goToStep(tester, 'review');
    expect(palette('wall'), findsNothing);
    expect(palette('circleTable'), findsNothing);
  });

  testWidgets('Table configuration: tap a table to edit it, but not move it', (
    tester,
  ) async {
    await openPage(tester);
    await goToStep(tester, 'tableConfiguration');
    expect(find.text('Table configuration'), findsOneWidget);

    // Tables at 100%, the room at 30%, as in Table & seat.
    final view = tester.widget<FloorPlanView>(find.byType(FloorPlanView));
    expect(view.dimTables, isFalse);
    expect(view.roomOpacity, 0.3);

    final table = find.byKey(const ValueKey('table-T1'));
    await tester.tapAt(tester.getCenter(table));
    await settle(tester);

    // The Edit panel opens; Edit and Save work, the rest are disabled.
    expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
    for (final (key, enabled) in [
      ('edit', true),
      ('save-item', true),
      ('move', false),
      ('duplicate', false),
      ('remove-item', false),
    ]) {
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(ValueKey(key)),
      );
      expect(button.onPressed != null, enabled, reason: key);
    }

    // A double tap doesn't start moving it.
    final before = tester.getCenter(table);
    await tester.tapAt(before);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(before);
    await settle(tester);
    expect(find.byKey(const ValueKey('moving-badge')), findsNothing);
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
    await settle(tester);

    expect(moveButton, findsOneWidget);
    expect(editButton, findsOneWidget);
    expect(find.byKey(const ValueKey('save-item')), findsOneWidget);
    expect(find.text('1 · Table · roundedRect'), findsOneWidget);

    // Tapping empty floor clears the selection.
    await tester.tapAt(floorPoint(tester, const Offset(20, 21)));
    await settle(tester);
    expectNothingSelected(tester);
  });

  testWidgets('each step fades the other step\'s items; rulers in every '
      'step', (tester) async {
    final topRuler = find.byKey(const ValueKey('ruler-top'));
    final leftRuler = find.byKey(const ValueKey('ruler-left'));
    final t1 = find.byKey(const ValueKey('table-T1'));
    final kitchen = find.text('Kitchen');
    // The fade is inside a table's widget, and around a fixture's label.
    double opacityOf(Finder f) {
      final inside = find.descendant(of: f, matching: find.byType(Opacity));
      final around = find.ancestor(of: f, matching: find.byType(Opacity));
      return tester
          .widget<Opacity>(
            inside.evaluate().isNotEmpty ? inside.first : around.first,
          )
          .opacity;
    }

    await openPage(tester);

    // Step 1: tables at 30%, the room at 100%.
    expect(t1, findsOneWidget);
    expect(opacityOf(t1), 0.3);
    expect(opacityOf(kitchen), 1);
    expect(topRuler, findsOneWidget);
    expect(leftRuler, findsOneWidget);

    // Tapping table 1 still selects nothing in step 1.
    final table = plan.tableById('T1')!;
    await tester.tapAt(floorPoint(tester, Offset(table.x, table.y)));
    await settle(tester);
    expectNothingSelected(tester);

    // Step 2: the room's items at 30%, the tables at 100%.
    await goToStep(tester, 'tableAndSeat');
    expect(opacityOf(t1), 1);
    expect(opacityOf(kitchen), 0.3);
    expect(topRuler, findsOneWidget);

    // Review: everything at 100%.
    await goToStep(tester, 'review');
    expect(opacityOf(t1), 1);
    expect(opacityOf(kitchen), 1);
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

    // Selecting the entrance door fills in the name; the bar stays put (the
    // Edit panel opening narrows the floor, but the ruler stays as high).
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await settle(tester);
    expect(
      tester.getRect(find.byKey(const ValueKey('ruler-top'))).top,
      ruler.top,
    );
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
    await settle(tester);
    expect(level(), '150%');
    expect(floor().width, closeTo(before.width * 1.5, 0.01));
    expect(floor().center.dx, closeTo(before.center.dx, 0.01));

    // Up to 600% at most.
    final up = <String>[];
    for (var i = 0; i < 10 && enabled(zoomIn); i++) {
      await tester.tap(zoomIn);
      await settle(tester);
      up.add(level());
    }
    expect(up, ['200%', '300%', '400%', '600%']);

    // Down to 25% at least: smaller than the view, still centered.
    final down = <String>[];
    for (var i = 0; i < 10 && enabled(zoomOut); i++) {
      await tester.tap(zoomOut);
      await settle(tester);
      down.add(level());
    }
    expect(down, ['400%', '300%', '200%', '150%', '100%', '75%', '50%', '25%']);
    expect(floor().width, closeTo(before.width / 4, 0.01));
    expect(floor().center.dx, closeTo(before.center.dx, 0.01));
    expect(floor().center.dy, closeTo(before.center.dy, 0.01));

    // And back to 100%: the floor fits the view again.
    for (var i = 0; i < 3; i++) {
      await tester.tap(zoomIn);
      await settle(tester);
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
    await settle(tester);
    expect(level(), '200%');
    expect(allTablesShown(), isFalse);

    await goToStep(tester, 'review');
    expect(level(), '100%');
    expect(allTablesShown(), isTrue);
  });

  testWidgets('tables past the room are in view at 100%, Review too', (
    tester,
  ) async {
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
    await settle(tester);
    final table = find.byKey(const ValueKey('table-T1'));
    String level() =>
        tester.widget<Text>(find.byKey(const ValueKey('zoom-level'))).data!;

    for (final step in ['tableAndSeat', 'review']) {
      await goToStep(tester, step);
      expect(level(), '100%', reason: step);
      final view = tester.getRect(find.byType(InteractiveViewer));
      expect(
        view.contains(tester.getRect(table).topRight),
        isTrue,
        reason: step,
      );
    }
  });

  testWidgets('a table outside the walls can be tapped and removed', (
    tester,
  ) async {
    // T3 sits above the room's top wall.
    repository = _MemoryRepository(
      FloorPlan.parse('''
        {"id": "p", "width": 40, "height": 24,
         "tables": [{"id": "T3", "label": "3", "shape": "rect",
                     "x": 20, "y": -3, "width": 2, "height": 2}]}
      '''),
    );
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: repository)),
    );
    await settle(tester);
    await goToStep(tester, 'tableAndSeat');

    final t3 = find.byKey(const ValueKey('table-T3'));
    // The floor takes the tap, not the table widget itself.
    await tester.tap(t3, warnIfMissed: false);
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('selection-title'))).data,
      '3 · Table · rect',
    );

    await tester.tap(find.byKey(const ValueKey('remove-item')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-remove')));
    await settle(tester);
    expect(t3, findsNothing);
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
    await settle(tester);
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
    await settle(tester);
    // The room box now spans x 0..47.
    Offset at(Offset units) {
      final room = tester.getRect(find.byType(DragTarget<PaletteItem>));
      return room.topLeft + units * (room.width / 47);
    }

    await tester.tapAt(at(const Offset(46.9, 6)));
    await settle(tester);
    expect(find.textContaining('Window · 1.5 m'), findsWidgets);

    await tester.tapAt(at(const Offset(46.9, 18)));
    await settle(tester);
    expect(find.text('Outer wall · (47, 0) → (47, 24)'), findsOneWidget);
  });

  testWidgets('zoom buttons are frozen in Move mode', (tester) async {
    await openPage(tester);
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await settle(tester);
    await tester.tap(moveButton);
    await settle(tester);
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
    await settle(tester);
    expect(find.text('Entrance · Door · 1.5 m'), findsOneWidget);
  });

  testWidgets('tapping a wall shows its start and end', (tester) async {
    await openPage(tester);

    // The inner kitchen wall.
    await tester.tapAt(floorPoint(tester, const Offset(30, 5)));
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('selection-title'))).data,
      'Wall · (30, 0) → (40, 10)',
    );

    // An outer wall: selectable and movable, but has no name to edit.
    await tester.tapAt(floorPoint(tester, const Offset(10, 23.9)));
    await settle(tester);
    expect(find.textContaining('Outer wall · '), findsOneWidget);
    final edit = tester.widget<ButtonStyleButton>(editButton);
    expect(edit.onPressed, isNull);
    expect(moveButton, findsOneWidget);
  });

  testWidgets('double-tapping an item starts moving it', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    final t1 = find.byKey(const ValueKey('table-T1'));
    final before = plan.tableById('T1')!;

    await tester.tap(t1);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(t1);
    await settle(tester);

    // Selected and in Move mode (Move shows Done ✓); no Edit panel.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('selection-title'))).data,
      '1 · Table · roundedRect',
    );
    expect(
      find.descendant(of: moveButton, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('item-name')), findsNothing);

    // Dragging now moves the table.
    final start = tester.getCenter(t1);
    final gesture = await tester.startGesture(start);
    final step =
        (floorPoint(tester, const Offset(2, 0)) -
            floorPoint(tester, Offset.zero)) /
        10;
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(step);
      await tester.pump();
    }
    await gesture.up();
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    expect(repository.saved!.tableById('T1')!.x, closeTo(before.x + 2, 0.11));
  });

  group('double tap while editing or moving', () {
    Future<void> doubleTap(WidgetTester tester, Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(at);
      await settle(tester);
    }

    String? titleText(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('selection-title'))).data;

    final badge = find.byKey(const ValueKey('moving-badge'));
    Offset tableAt(WidgetTester tester, String id) =>
        tester.getCenter(find.byKey(ValueKey('table-$id')));

    testWidgets('a moving item is boxed, with a move badge top left', (
      tester,
    ) async {
      await openPage(tester);
      await goToStep(tester, 'tableAndSeat');
      expect(badge, findsNothing);
      await doubleTap(tester, tableAt(tester, 'T1'));
      expect(badge, findsOneWidget);
      // At the top-left corner of the table and its seats.
      final table = tester.getRect(find.byKey(const ValueKey('table-T1')));
      final b = tester.getCenter(badge);
      expect(b.dx, lessThan(table.left));
      expect(b.dy, lessThan(table.top));

      // Done turns move mode off, and the badge goes.
      await tester.tap(moveButton);
      await settle(tester);
      expect(badge, findsNothing);
    });

    testWidgets('on empty floor: saves and lets go of the edited item', (
      tester,
    ) async {
      await openPage(tester);
      await goToStep(tester, 'tableAndSeat');
      await tester.tap(find.byKey(const ValueKey('table-T1')));
      await settle(tester);
      expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('item-name')), 'A9');
      await settle(tester);

      await doubleTap(tester, floorPoint(tester, const Offset(20, 18)));
      expectNothingSelected(tester);
      expect(find.byKey(const ValueKey('item-name')), findsNothing);
      expect(repository.saved!.tableById('T1')!.label, 'A9');
    });

    testWidgets('on empty floor: saves and lets go of the moving item', (
      tester,
    ) async {
      await openPage(tester);
      await goToStep(tester, 'tableAndSeat');
      await doubleTap(tester, tableAt(tester, 'T1'));
      expect(badge, findsOneWidget);

      await doubleTap(tester, floorPoint(tester, const Offset(20, 18)));
      expectNothingSelected(tester);
      expect(badge, findsNothing);
      expect(repository.saved, isNotNull);
    });

    testWidgets('on another item: saves, then moves that item', (tester) async {
      await openPage(tester);
      await goToStep(tester, 'tableAndSeat');
      await doubleTap(tester, tableAt(tester, 'T1'));
      expect(titleText(tester), startsWith('1 · '));

      await doubleTap(tester, tableAt(tester, 'T2'));
      expect(repository.saved, isNotNull);
      expect(titleText(tester), startsWith('2 · '));
      expect(
        find.descendant(of: moveButton, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(badge, findsOneWidget);
    });

    testWidgets('on another item while editing: saves, then moves it', (
      tester,
    ) async {
      await openPage(tester);
      await goToStep(tester, 'tableAndSeat');
      await tester.tap(find.byKey(const ValueKey('table-T1')));
      await settle(tester);
      expect(find.byKey(const ValueKey('item-name')), findsOneWidget);

      await doubleTap(tester, tableAt(tester, 'T2'));
      expect(repository.saved, isNotNull);
      expect(titleText(tester), startsWith('2 · '));
      expect(find.byKey(const ValueKey('item-name')), findsNothing);
      expect(badge, findsOneWidget);
    });

    testWidgets('nothing selected: no save', (tester) async {
      await openPage(tester);
      await goToStep(tester, 'tableAndSeat');
      await doubleTap(tester, tableAt(tester, 'T2'));
      expect(repository.saved, isNull);
      expect(badge, findsOneWidget);
    });
  });

  testWidgets('double-tapping empty floor does nothing', (tester) async {
    await openPage(tester);
    final at = floorPoint(tester, const Offset(20, 18));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(at);
    await settle(tester);
    expectNothingSelected(tester);
  });

  testWidgets('the bar\'s buttons: Edit, Move, Save, Duplicate, Remove; '
      'icons only', (tester) async {
    await openPage(tester);
    final keys = ['edit', 'move', 'save-item', 'duplicate', 'remove-item'];
    final lefts = [
      for (final key in keys) tester.getRect(find.byKey(ValueKey(key))).left,
    ];
    expect(lefts, [...lefts]..sort());
    // A separator between Save and Duplicate.
    final separator = tester.getRect(
      find.byKey(const ValueKey('bar-separator')),
    );
    expect(
      separator.left,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('save-item'))).right,
      ),
    );
    expect(
      separator.right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('duplicate'))).left,
      ),
    );
    for (final (key, label) in [
      ('edit', 'Edit'),
      ('move', 'Move'),
      ('save-item', 'Save'),
      ('duplicate', 'Duplicate'),
      ('remove-item', 'Remove'),
    ]) {
      final button = find.byKey(ValueKey(key));
      expect(
        find.descendant(of: button, matching: find.byType(Text)),
        findsNothing,
        reason: '$key has no label',
      );
      expect(
        find.ancestor(of: button, matching: find.byTooltip(label)),
        findsOneWidget,
        reason: '$key tooltip',
      );
    }
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
      await settle(tester);
    }

    // Select the bottom outer wall, (40, 24) → (0, 24), and turn on Move.
    // (Its ends are clear of the toolbar at the top right.)
    await tester.tapAt(floorPoint(tester, const Offset(10, 23.9)));
    await settle(tester);
    expect(find.text('Outer wall · (40, 24) → (0, 24)'), findsOneWidget);
    await tester.tap(moveButton);
    await settle(tester);
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
    await settle(tester);
    final outline = repository.saved!.floorOutline;
    expect(outline, contains(const Offset(40, 23)));
    expect(outline, contains(const Offset(2, 24)));
    expect(outline, isNot(contains(const Offset(0, 24))));
  });

  testWidgets('review mode: items cannot be selected', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'review');

    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await settle(tester);
    expectNothingSelected(tester);
  });

  testWidgets(
    'tapping an item opens the Edit panel without focusing a text field',
    (tester) async {
      await openPage(tester);
      // A door: its panel has the most fields (name, wall, length).
      await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
      await settle(tester);

      expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('item-length')), findsOneWidget);
      // No text field has focus, so no keyboard opens.
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(
        focused == null ||
            focused.findAncestorWidgetOfExactType<EditableText>() == null &&
                focused.widget is! EditableText,
        isTrue,
      );
      expect(tester.testTextInput.hasAnyClients, isFalse);

      // Tapping the name field still focuses it.
      await tester.tap(find.byKey(const ValueKey('item-name')));
      await settle(tester);
      expect(tester.testTextInput.hasAnyClients, isTrue);
    },
  );

  testWidgets('Edit renames the item, Save writes it', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await settle(tester);

    // Capitals only; anything but letters and digits is dropped.
    await tester.enterText(
      find.byKey(const ValueKey('item-name')),
      'win dow-2!',
    );
    await settle(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('item-name')))
          .controller!
          .text,
      'WINDOW2',
    );
    // The new name shows on the floor right away.
    expect(find.text('WINDOW2'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    expect(repository.saved!.tableById('T1')!.label, 'WINDOW2');
    expect(find.text('Saved to memory'), findsOneWidget);
  });

  testWidgets('room and decor names keep their case', (tester) async {
    await openPage(tester);
    // The inner kitchen wall.
    await tester.tapAt(floorPoint(tester, const Offset(30, 5)));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('item-name')),
      'Back wall-1',
    );
    await settle(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('item-name')))
          .controller!
          .text,
      'Backwall1',
    );
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
    await settle(tester);
    // Tapping it opened the Edit panel, which no longer has a Remove button.
    expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
    expect(removeButton, findsOneWidget); // Only the one in the bar.

    // Remove → the question; ✕ keeps the table.
    expect(question, findsNothing);
    await tester.tap(removeButton);
    await settle(tester);
    expect(question, findsOneWidget);
    await tester.tap(cancel);
    await settle(tester);
    expect(question, findsNothing);
    expect(table1, findsOneWidget);

    // Remove → ✓ removes it; the selection and side bar close.
    await tester.tap(removeButton);
    await settle(tester);
    await tester.tap(confirm);
    await settle(tester);
    expect(table1, findsNothing);
    expect(question, findsNothing);
    expect(find.byKey(const ValueKey('item-name')), findsNothing);
    expectNothingSelected(tester);
    expect(find.text('Removed 1'), findsOneWidget);

    // Undo brings it back, selected again.
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(table1, findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(removeButton).onPressed, isNotNull);

    // Remove again and save: the saved plan has no table 1.
    await tester.tap(removeButton);
    await settle(tester);
    await tester.tap(confirm);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    expect(repository.saved!.tableById('T1'), isNull);
    expect(repository.saved!.tables, hasLength(plan.tables.length - 1));
  });

  testWidgets('the Remove question floats under the button; the floor '
      'stays put', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await settle(tester);
    Rect floor() => tester.getRect(find.byType(DragTarget<PaletteItem>));
    final before = floor();

    final remove = find.byKey(const ValueKey('remove-item'));
    await tester.tap(remove);
    await settle(tester);
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
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('remove-item')));
    await settle(tester);
    expect(find.text('Remove item?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('table-T2')));
    await settle(tester);
    expect(find.text('Remove item?'), findsNothing);

    // And back on table 1: still closed.
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await settle(tester);
    expect(find.text('Remove item?'), findsNothing);
  });

  testWidgets('Remove works for room items too', (tester) async {
    await openPage(tester);
    final before = plan.elements.whereType<DoorElement>().length;

    // The entrance door.
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('remove-item')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-remove')));
    await settle(tester);
    expect(find.text('Removed Entrance'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    expect(
      repository.saved!.elements.whereType<DoorElement>(),
      hasLength(before - 1),
    );
  });

  testWidgets(
    'Duplicate copies a table (inside the room) 0.2 m right and down',
    (tester) async {
      await openPage(tester);
      await goToStep(tester, 'tableAndSeat');
      await tester.tap(find.byKey(const ValueKey('table-T5')));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('duplicate')));
      await settle(tester);
      // The copy is the next table, and it's selected.
      expect(find.byKey(const ValueKey('table-T8')), findsOneWidget);
      expect(find.text('Duplicated 5'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('selection-title'))).data,
        '8 · Table · roundedRect',
      );

      await tester.tap(find.byKey(const ValueKey('save')));
      await settle(tester);
      final original = repository.saved!.tableById('T5')!;
      final copy = repository.saved!.tableById('T8')!;
      // 0.2 m = 0.4 units at 0.5 m per unit.
      expect(copy.x, closeTo(original.x + 0.4, 1e-9));
      expect(copy.y, closeTo(original.y + 0.4, 1e-9));
      expect(
        (copy.width, copy.height, copy.shape.shape),
        (original.width, original.height, original.shape.shape),
      );
      expect(copy.seats, hasLength(original.seats.length));
    },
  );

  testWidgets('outer walls can\'t be duplicated or removed', (tester) async {
    await openPage(tester);
    await tester.tapAt(floorPoint(tester, const Offset(10, 23.9)));
    await settle(tester);
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
    await settle(tester);
    expect(tester.widget<TextField>(length).controller!.text, '1.5');

    // + twice: 1.7 m. The toolbar shows the new length right away.
    await tester.tap(find.byKey(const ValueKey('length-plus')));
    await tester.tap(find.byKey(const ValueKey('length-plus')));
    await settle(tester);
    expect(find.text('Entrance · Door · 1.7 m'), findsOneWidget);

    // Typing works too, and a bad value is refused with a message.
    await tester.enterText(length, 'abc');
    await settle(tester);
    expect(find.textContaining('Enter a length'), findsOneWidget);
    expect(find.text('Entrance · Door · 1.7 m'), findsOneWidget);
    await tester.enterText(length, '2,25');
    await settle(tester);
    expect(find.textContaining('Enter a length'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final door = repository.saved!.elements.whereType<DoorElement>().first;
    expect(door.width, 4.5); // 2.25 m / 0.5 m per unit
  });

  testWidgets('tables have no length field', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await settle(tester);
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
    await settle(tester);
    expect(find.text('Kitchen · Fixture · 4.8 × 4.8 m'), findsOneWidget);
    expect(text(width), '4.8');
    expect(text(height), '4.8');
    expect(find.byKey(const ValueKey('item-length')), findsNothing);
    expect(find.byKey(const ValueKey('item-diameter')), findsNothing);

    await tester.enterText(width, '3');
    await tester.tap(find.byKey(const ValueKey('height-minus')));
    await settle(tester);
    expect(text(height), '4.7');
    expect(find.text('Kitchen · Fixture · 3 × 4.7 m'), findsWidgets);

    // Out of range: shows an error and keeps the last good size.
    await tester.enterText(width, '0.1');
    await settle(tester);
    expect(find.textContaining('Enter a width from'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final kitchen = repository.saved!.elements
        .whereType<FixtureElement>()
        .firstWhere((f) => f.label == 'Kitchen');
    expect(kitchen.width, 6); // 3 m
    expect(kitchen.height, closeTo(9.4, 1e-9)); // 4.7 m
    expect((kitchen.x, kitchen.y), (35, 5)); // Same center.
  });

  testWidgets('Edit turns a fixture', (tester) async {
    await openPage(tester);
    // The kitchen, at (35, 5).
    await tester.tapAt(floorPoint(tester, const Offset(35, 5)));
    await settle(tester);
    final slider = find.byKey(const ValueKey('item-rotation'));
    expect(slider, findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('item-rotation-value')))
          .data,
      '0°',
    );

    tester.widget<Slider>(slider).onChanged!(45);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final kitchen = repository.saved!.elements
        .whereType<FixtureElement>()
        .firstWhere((f) => f.label == 'Kitchen');
    expect(kitchen.rotation, 45);
    expect((kitchen.x, kitchen.y), (35, 5)); // Turned around its center.
  });

  testWidgets('doors have no rotation slider', (tester) async {
    await openPage(tester);
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await settle(tester);
    expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('item-rotation')), findsNothing);
  });

  testWidgets('Edit sets a plant\'s diameter', (tester) async {
    final diameter = find.byKey(const ValueKey('item-diameter'));
    await openPage(tester);

    // A plant: 1.6 units = 0.8 m across, centered at (15.2, 13.2).
    await tester.tapAt(floorPoint(tester, const Offset(15.2, 13.2)));
    await settle(tester);
    expect(find.byKey(const ValueKey('item-width')), findsNothing);
    expect(tester.widget<TextField>(diameter).controller!.text, '0.8');

    await tester.tap(find.byKey(const ValueKey('diameter-plus')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
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
    await settle(tester);

    // Currently on the bottom outer wall.
    expect(find.text('Outer wall 5 · (40, 24) → (0, 24)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('item-wall')));
    await settle(tester);
    await tester.tap(find.text('Outer wall 4 · (40, 0) → (40, 24)').last);
    await settle(tester);
    expect(find.text('Outer wall 4 · (40, 0) → (40, 24)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final door = repository.saved!.elements.whereType<DoorElement>().firstWhere(
      (d) => d.label == 'Entrance',
    );
    // On the right wall, as close to where it was as fits, turned upright.
    expect((door.x, door.y, door.angle), (40.0, 22.5, 90.0));
  });

  testWidgets('Move slides a door onto the nearest wall', (tester) async {
    await openPage(tester);
    await tester.tapAt(floorPoint(tester, const Offset(20, 23.9)));
    await settle(tester);
    await tester.tap(moveButton);
    await settle(tester);
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
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('save-item')));
    await settle(tester);
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
    await settle(tester);
    await tester.tap(moveButton);
    await settle(tester);
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
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('save-item')));
    await settle(tester);
    final after = repository.saved!.tableById('T1')!;
    expect(after.x - before.x, closeTo(3, 0.01));
    expect(after.y, before.y);
  });

  group('rounded rectangle and square tables', () {
    Finder side(String name) => find.byKey(ValueKey('seat-side-$name'));
    Color seatColor(WidgetTester tester, String name) {
      final seat = find
          .descendant(of: side(name), matching: find.byType(Container))
          .first;
      final decoration =
          tester.widget<Container>(seat).decoration! as BoxDecoration;
      return decoration.color!;
    }

    testWidgets('adding one opens the Edit panel with seats and rotation', (
      tester,
    ) async {
      await openTall(tester);
      await goToStep(tester, 'tableAndSeat');
      await tester.tap(palette('roundedRectTable'));
      await settle(tester);

      expect(find.text('Added Table 8'), findsOneWidget);
      expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      // Six seats: two top, two bottom, one each end; all included.
      for (final (name, count) in [
        ('top', 2),
        ('bottom', 2),
        ('left', 1),
        ('right', 1),
      ]) {
        expect(
          find.descendant(of: side(name), matching: find.byType(Container)),
          findsNWidgets(count),
          reason: name,
        );
        expect(seatColor(tester, name), Colors.green, reason: name);
      }
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('item-rotation-value')))
            .data,
        '0°',
      );
    });

    testWidgets('tapping a side removes or adds its seats', (tester) async {
      await openTall(tester);
      await goToStep(tester, 'tableAndSeat');
      await tester.tap(palette('roundedRectTable'));
      await settle(tester);

      await tester.tap(side('top'));
      await tester.tap(side('left'));
      await settle(tester);
      expect(seatColor(tester, 'top'), isNot(Colors.green));
      expect(seatColor(tester, 'left'), isNot(Colors.green));
      expect(seatColor(tester, 'bottom'), Colors.green);
      // Excluded sides still show where their seats would go.
      expect(
        find.descendant(of: side('top'), matching: find.byType(Container)),
        findsNWidgets(2),
      );

      await tester.tap(find.byKey(const ValueKey('save')));
      await settle(tester);
      final table = repository.saved!.tableById('T8')!;
      expect(
        (
          table.seatLayout.top,
          table.seatLayout.bottom,
          table.seatLayout.left,
          table.seatLayout.right,
        ),
        (0, 2, 0, 1),
      );
      expect(table.seats, hasLength(3));

      // And back on.
      await tester.tap(side('top'));
      await settle(tester);
      expect(seatColor(tester, 'top'), Colors.green);
    });

    testWidgets('the slider turns the table', (tester) async {
      await openTall(tester);
      await goToStep(tester, 'tableAndSeat');
      await tester.tap(palette('roundedRectTable'));
      await settle(tester);

      final slider = find.byKey(const ValueKey('item-rotation'));
      expect(tester.widget<Slider>(slider).divisions, 23); // 15° steps.
      tester.widget<Slider>(slider).onChanged!(90);
      await settle(tester);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('item-rotation-value')))
            .data,
        '90°',
      );
      await tester.tap(find.byKey(const ValueKey('save')));
      await settle(tester);
      expect(repository.saved!.tableById('T8')!.rotation, 90);
    });

    testWidgets('the rounded square has one seat per side', (tester) async {
      await openTall(tester);
      await goToStep(tester, 'tableAndSeat');
      expect(palette('roundedSquareTable'), findsOneWidget);
      await tester.tap(palette('roundedSquareTable'));
      await settle(tester);

      for (final name in ['top', 'bottom', 'left', 'right']) {
        expect(
          find.descendant(of: side(name), matching: find.byType(Container)),
          findsOneWidget,
          reason: name,
        );
      }
      await tester.tap(find.byKey(const ValueKey('save')));
      await settle(tester);
      final table = repository.saved!.tableById('T8')!;
      // 0.7 m a side by default, 0.5 m per floor unit.
      expect((table.width, table.height), (1.4, 1.4));
      expect(table.square, isTrue);
      expect(table.seats, hasLength(4));
    });

    testWidgets('other tables have no seat picture or rotation', (
      tester,
    ) async {
      await openTall(tester);
      await goToStep(tester, 'tableAndSeat');
      // A semicircle booth: no seat picker and no rotation.
      await tester.tap(find.byKey(const ValueKey('table-B1')));
      await settle(tester);
      expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
      expect(side('top'), findsNothing);
      expect(find.byKey(const ValueKey('item-rotation')), findsNothing);
    });
  });

  testWidgets('dragging a table out past the walls moves it exactly as far', (
    tester,
  ) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');
    final before = plan.tableById('T1')!; // At (5, 10).
    await tester.tap(find.byKey(const ValueKey('table-T1')));
    await settle(tester);
    await tester.tap(moveButton);
    await settle(tester);

    // 8 units left: 3 units past the left wall. Going past the walls would
    // re-fit the floor; it must not while moving, or the drag runs away.
    final start = floorPoint(tester, Offset(before.x, before.y));
    final step =
        (floorPoint(tester, Offset(before.x - 8, before.y)) - start) / 20;
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(step);
      await tester.pump();
    }
    await gesture.up();
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('save-item')));
    await settle(tester);
    final after = repository.saved!.tableById('T1')!;
    expect(after.x, closeTo(before.x - 8, 0.11));
    expect(after.y, closeTo(before.y, 0.11));
  });

  group('tables stay inside the room', () {
    // The fixture room is L-shaped: x 0–26 only below y = 12. T6 is a round
    // table at (25, 19.5) with six seats.
    Future<void> drag(WidgetTester tester, Offset from, Offset by) async {
      final start = floorPoint(tester, from);
      final step = (floorPoint(tester, from + by) - start) / 20;
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      await gesture.up();
      await settle(tester);
    }

    Future<FloorTable> saved(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(const ValueKey('save')));
      await settle(tester);
      return repository.saved!.tableById(id)!;
    }

    testWidgets('dragging a table against a wall stops it there', (
      tester,
    ) async {
      await openTall(tester);
      await goToStep(tester, 'tableAndSeat');
      await tester.tap(find.byKey(const ValueKey('table-T6')));
      await settle(tester);
      await tester.tap(moveButton);
      await settle(tester);

      // 20 units down: far past the bottom wall (y = 24).
      await drag(tester, const Offset(25, 19.5), const Offset(0, 20));
      final t6 = await saved(tester, 'T6');
      expect(t6.y, lessThan(24));
      expect(t6.y, greaterThan(19.5)); // It did move, up to the wall.
      expect(tableInsideRoom(repository.saved!, t6), isTrue);
    });

    testWidgets('it slides along the wall when dragged at an angle', (
      tester,
    ) async {
      await openTall(tester);
      await goToStep(tester, 'tableAndSeat');
      await tester.tap(find.byKey(const ValueKey('table-T6')));
      await settle(tester);
      await tester.tap(moveButton);
      await settle(tester);

      // Down past the wall and 4 units right: it ends 4 units right.
      await drag(tester, const Offset(25, 19.5), const Offset(4, 20));
      final t6 = await saved(tester, 'T6');
      expect(t6.x, closeTo(29, 0.11));
      expect(tableInsideRoom(repository.saved!, t6), isTrue);
    });

    testWidgets('a table dropped outside the room lands inside', (
      tester,
    ) async {
      await openTall(tester);
      await goToStep(tester, 'tableAndSeat');
      // Drop a circle table in the L's cut-out, outside the walls.
      final gesture = await tester.startGesture(
        tester.getCenter(palette('circleTable')),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(floorPoint(tester, const Offset(10, 5)));
      await tester.pump();
      await gesture.up();
      await settle(tester);

      final added = await saved(tester, 'T8');
      expect(tableInsideRoom(repository.saved!, added), isTrue);
      // Nearest spot: just below the cut-out's wall (y = 12).
      expect(added.y, greaterThan(12));
      expect(added.y, lessThan(16));
    });
  });

  testWidgets('dragging works the same when tables sit outside the walls', (
    tester,
  ) async {
    // A table outside the walls makes the floor's tap box start above the
    // room; drags must still move exactly as far as the finger.
    repository = _MemoryRepository(
      FloorPlan.parse('''
        {"id": "p", "width": 40, "height": 24,
         "tables": [
           {"id": "T1", "label": "1", "shape": "rect",
            "x": 20, "y": 12, "width": 2, "height": 2},
           {"id": "T3", "label": "3", "shape": "rect",
            "x": 30, "y": -3, "width": 2, "height": 2}]}
      '''),
    );
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: repository)),
    );
    await settle(tester);
    await goToStep(tester, 'tableAndSeat');
    final t1 = find.byKey(const ValueKey('table-T1'));
    await tester.tap(t1, warnIfMissed: false);
    await settle(tester);
    await tester.tap(moveButton);
    await settle(tester);

    final start = tester.getCenter(t1);
    final unit = tester.getSize(t1).width / 2; // The table is 2 units wide.
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(unit * 3 / 20, 0));
      await tester.pump();
    }
    await gesture.up();
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final moved = repository.saved!.tableById('T1')!;
    expect(moved.x, closeTo(23, 0.11));
    expect(moved.y, closeTo(12, 0.11));
  });

  testWidgets('Table configuration › Bar sets the slot for every bar', (
    tester,
  ) async {
    // Tall enough for the panel's Table configuration section.
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openPage(tester);
    // Not in step 1.
    expect(find.byKey(const ValueKey('config-bar')), findsNothing);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(palette('barTable')); // A 4-seat bar.
    await settle(tester);

    final config = find.byKey(const ValueKey('config-bar'));
    expect(config, findsOneWidget);
    await tester.tap(config);
    await settle(tester);

    await tester.enterText(find.byKey(const ValueKey('bar-slot-width')), '0.6');
    await tester.enterText(find.byKey(const ValueKey('bar-slot-depth')), '0.3');
    await tester.tap(find.byKey(const ValueKey('bar-slot-save')));
    await settle(tester);
    expect(find.text('Enter 0.4 to 0.6 m'), findsOneWidget); // Too shallow.
    await tester.enterText(find.byKey(const ValueKey('bar-slot-depth')), '0.5');
    await tester.tap(find.byKey(const ValueKey('bar-slot-save')));
    await settle(tester);
    expect(find.text('Per seat: 0.6 m wide × 0.5 m deep'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final saved = repository.saved!;
    final bar = saved.tables.lastWhere((t) => t.bar);
    expect(bar.width * saved.metersPerUnit, closeTo(2.4, 1e-9));
    expect(bar.height * saved.metersPerUnit, closeTo(0.5, 1e-9));
    expect((saved.barSlotWidth, saved.barSlotDepth), (0.6, 0.5));
  });

  testWidgets('panel: Rectangle and Square names, four table settings', (
    tester,
  ) async {
    await openTall(tester);
    await goToStep(tester, 'tableAndSeat');
    expect(find.text('Rectangle'), findsWidgets);
    expect(find.text('Square'), findsWidgets);
    expect(find.text('Rounded rectangle'), findsNothing);
    expect(find.text('Rounded square'), findsNothing);
    for (final key in [
      'rectangle',
      'square',
      'bar',
      'circle',
      'quarter-circle',
    ]) {
      expect(find.byKey(ValueKey('config-$key')), findsOneWidget);
    }
  });

  testWidgets('Table configuration › Rectangle resizes rectangle tables', (
    tester,
  ) async {
    await openTall(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(palette('roundedRectTable')); // 2 + 2, 1 + 1 seats.
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('config-rectangle')));
    await settle(tester);

    await tester.enterText(
      find.byKey(const ValueKey('rectangle-width')),
      '1.2',
    );
    await tester.tap(find.byKey(const ValueKey('rectangle-save')));
    await settle(tester);
    expect(find.text('Enter 0.6 to 0.8 m'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rectangle-width')),
      '0.8',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rectangle-depth')),
      '0.6',
    );
    await tester.enterText(find.byKey(const ValueKey('rectangle-buffer')), '0');
    await tester.tap(find.byKey(const ValueKey('rectangle-save')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final saved = repository.saved!;
    final t8 = saved.tableById('T8')!;
    // Length: 2 × 0.8 + 3 × 0 = 1.6 m;
    // width: max(1 × 0.8 + 0, 2 × 0.6 + 0.2) = 1.4 m.
    expect(t8.width * saved.metersPerUnit, closeTo(1.6, 1e-9));
    expect(t8.height * saved.metersPerUnit, closeTo(1.4, 1e-9));
    expect(t8.square, isFalse);
  });

  testWidgets('rectangle Edit panel: seats on the width and length side', (
    tester,
  ) async {
    await openTall(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(palette('roundedRectTable'));
    await settle(tester);
    final width = find.byKey(const ValueKey('rect-width-seats'));
    final length = find.byKey(const ValueKey('rect-length-seats'));
    String text(Finder f) => tester.widget<TextField>(f).controller!.text;
    expect((text(width), text(length)), ('1', '2'));
    // Between the seat picture and the rotation slider.
    final picture = tester.getRect(find.byKey(const ValueKey('seat-side-top')));
    final rotation = tester.getRect(
      find.byKey(const ValueKey('item-rotation')),
    );
    expect(tester.getRect(width).top, greaterThan(picture.bottom));
    expect(tester.getRect(length).bottom, lessThan(rotation.top));

    // Out of range.
    await tester.enterText(length, '5');
    await settle(tester);
    expect(find.text('Enter 2 to 4 seats'), findsOneWidget);
    await tester.enterText(length, '2');
    await tester.enterText(width, '3');
    await settle(tester);
    expect(find.text('Enter 1 to 2 seats'), findsOneWidget);

    // Length must be more than width.
    await tester.enterText(width, '2');
    await settle(tester);
    expect(find.text('Must be more than the width side (2)'), findsOneWidget);

    await tester.enterText(length, '4');
    await settle(tester);
    expect(find.textContaining('Must be more'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final t8 = repository.saved!.tableById('T8')!;
    expect(rectangleSeats(t8), (long: 4, ends: 2));
    expect(t8.seats, hasLength(12));
    // Default settings: length 4 × 0.6 + 5 × 0.1 = 2.9 m;
    // width max(2 × 0.6 + 0.2, 2 × 0.4 + 0.2) = 1.4 m.
    expect(t8.width * repository.saved!.metersPerUnit, closeTo(2.9, 1e-9));
    expect(t8.height * repository.saved!.metersPerUnit, closeTo(1.4, 1e-9));
  });

  testWidgets('squares have no seat counts; Square settings resize them', (
    tester,
  ) async {
    await openTall(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(palette('roundedSquareTable'));
    await settle(tester);
    expect(find.byKey(const ValueKey('rect-length-seats')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('config-square')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('square-width')), '0.8');
    await tester.tap(find.byKey(const ValueKey('square-save')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final t8 = repository.saved!.tableById('T8')!;
    expect(t8.width * repository.saved!.metersPerUnit, closeTo(0.8, 1e-9));
    expect(t8.height, t8.width);
  });

  testWidgets('Circle settings: radii in cm by seat count', (tester) async {
    await openTall(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(palette('circleTable'));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('config-circle')));
    await settle(tester);
    String text(String key) => tester
        .widget<TextField>(find.byKey(ValueKey('circle-$key')))
        .controller!
        .text;
    expect(
      [
        for (final n in ['4', '6', '8', '10']) text(n),
      ],
      ['45', '69', '76', '106'],
    );
    expect(find.text('40 to 50 cm'), findsOneWidget);

    // More than 5 cm from the default is refused.
    await tester.enterText(find.byKey(const ValueKey('circle-4')), '51');
    await tester.tap(find.byKey(const ValueKey('circle-save')));
    await settle(tester);
    expect(find.text('Enter 40 to 50 cm'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('circle-4')), '50');
    await tester.tap(find.byKey(const ValueKey('circle-save')));
    await settle(tester);
    expect(find.textContaining('4 seats: 50 cm'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final saved = repository.saved!;
    expect(saved.circleRadii[4], 0.5);
    // The new circle table has 4 seats, so it's now 1 m across.
    final added = saved.tables.last;
    expect(added.width * saved.metersPerUnit, closeTo(1, 1e-9));
  });

  testWidgets('Quarter circle settings: radii in cm by seat count', (
    tester,
  ) async {
    await openTall(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(palette('quarterCircleTable')); // 2 seats.
    await settle(tester);

    final tile = find.byKey(const ValueKey('config-quarter-circle'));
    await tester.scrollUntilVisible(tile, 100);
    await tester.tap(tile);
    await settle(tester);
    String text(String key) => tester
        .widget<TextField>(find.byKey(ValueKey('quarter-circle-$key')))
        .controller!
        .text;
    expect(
      [
        for (final n in ['1', '2', '3']) text(n),
      ],
      ['55', '62', '68'],
    );
    expect(find.text('57 to 67 cm'), findsOneWidget);

    // More than 5 cm from the default is refused.
    await tester.enterText(
      find.byKey(const ValueKey('quarter-circle-2')),
      '68',
    );
    await tester.tap(find.byKey(const ValueKey('quarter-circle-save')));
    await settle(tester);
    expect(find.text('Enter 57 to 67 cm'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('quarter-circle-2')),
      '60',
    );
    await tester.tap(find.byKey(const ValueKey('quarter-circle-save')));
    await settle(tester);
    expect(find.textContaining('2 seats: 60 cm'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final saved = repository.saved!;
    expect(saved.quarterCircleRadii[2], 0.6);
    // The new quarter circle has 2 seats, so it's now 60 cm.
    final added = saved.tables.last;
    expect(added.shape.shape, TableShape.quarterCircle);
    expect(added.width * saved.metersPerUnit, closeTo(0.6, 1e-9));
    expect(added.seats, hasLength(2));
  });

  testWidgets('quarter circle Edit panel: a seat count dropdown, then '
      'rotation', (tester) async {
    await openTall(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(palette('quarterCircleTable'));
    await settle(tester);
    await tester.tap(editButton);
    await settle(tester);

    final dropdown = find.byKey(const ValueKey('quarter-circle-seats'));
    final preview = find.byKey(const ValueKey('quarter-circle-preview'));
    expect(dropdown, findsOneWidget);
    expect(find.text('2 seats · radius 62 cm'), findsOneWidget);
    expect(
      tester.getTopLeft(dropdown).dy,
      greaterThan(tester.getTopLeft(preview).dy),
    );
    expect(
      tester.getTopLeft(dropdown).dy,
      lessThan(tester.getTopLeft(find.byType(Slider)).dy),
    );

    Finder previewSeats() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'quarter-circle-preview-seat-',
          ),
    );
    expect(previewSeats(), findsNWidgets(2));

    await tester.tap(dropdown);
    await settle(tester);
    await tester.tap(find.text('3 seats · radius 68 cm').last);
    await settle(tester);
    expect(previewSeats(), findsNWidgets(3));

    await tester.tap(dropdown);
    await settle(tester);
    await tester.tap(find.text('1 seat · radius 55 cm').last);
    await settle(tester);
    expect(previewSeats(), findsNWidgets(1));

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final saved = repository.saved!;
    final added = saved.tables.last;
    expect(added.seats, hasLength(1));
    expect(added.width * saved.metersPerUnit, closeTo(0.55, 1e-9));
  });

  testWidgets('circle Edit panel: a seat count dropdown before rotation', (
    tester,
  ) async {
    await openTall(tester);
    await goToStep(tester, 'tableAndSeat');
    await tester.tap(palette('circleTable'));
    await settle(tester);
    await tester.tap(editButton);
    await settle(tester);

    final dropdown = find.byKey(const ValueKey('circle-seats'));
    expect(dropdown, findsOneWidget);
    expect(find.text('4 seats · radius 45 cm'), findsOneWidget);
    expect(find.byKey(const ValueKey('circle-preview')), findsOneWidget);
    // Between the Seats picture and the rotation slider.
    expect(
      tester.getTopLeft(dropdown).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('circle-preview'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(dropdown).dy,
      lessThan(tester.getTopLeft(find.byType(Slider)).dy),
    );

    await tester.tap(dropdown);
    await settle(tester);
    await tester.tap(find.text('8 seats · radius 76 cm').last);
    await settle(tester);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'circle-preview-seat-',
            ),
      ),
      findsNWidgets(8),
    );

    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final saved = repository.saved!;
    final added = saved.tables.last;
    expect(added.seats, hasLength(8));
    expect(added.width * saved.metersPerUnit, closeTo(1.52, 1e-9));
  });

  group('bar', () {
    Finder previewSeats() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('bar-preview-seat-'),
    );

    Future<void> addBar(WidgetTester tester) async {
      await openPage(tester);
      await goToStep(tester, 'tableAndSeat');
      expect(palette('barTable'), findsOneWidget);
      await tester.tap(palette('barTable'));
      await settle(tester);
    }

    testWidgets('adding a bar opens its Edit panel', (tester) async {
      await addBar(tester);
      // The plan already has a "Bar", so this is Bar 2.
      expect(find.text('Added Bar 2'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('selection-title'))).data,
        'Bar 2 · Bar · 4 seats',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('item-name')))
            .controller!
            .text,
        'Bar 2',
      );
      expect(previewSeats(), findsNWidgets(4));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bar-seats')))
            .controller!
            .text,
        '4',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('item-rotation-value')))
            .data,
        '0°',
      );
      // Not the rounded tables' side picker.
      expect(find.byKey(const ValueKey('seat-side-top')), findsNothing);
    });

    testWidgets('the seat count changes the bar, up to 10', (tester) async {
      await addBar(tester);
      final field = find.byKey(const ValueKey('bar-seats'));

      await tester.enterText(field, '7');
      await settle(tester);
      expect(previewSeats(), findsNWidgets(7));

      await tester.enterText(field, '11');
      await settle(tester);
      expect(find.text('Enter 1 to 10 seats'), findsOneWidget);
      expect(previewSeats(), findsNWidgets(7)); // Unchanged.

      await tester.enterText(field, '10');
      await settle(tester);
      final plus = find.byKey(const ValueKey('bar-seats-plus'));
      expect(tester.widget<IconButton>(plus).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('bar-seats-minus')));
      await settle(tester);
      expect(tester.widget<TextField>(field).controller!.text, '9');

      await tester.tap(find.byKey(const ValueKey('save')));
      await settle(tester);
      final bar = repository.saved!.tables.last;
      expect(bar.bar, isTrue);
      expect(bar.seats, hasLength(9));
      expect(bar.seatLayout.bottom, 9); // All on one side.
      // 0.6 m of counter per seat (the default), 0.5 m per floor unit.
      expect(bar.width, closeTo(10.8, 1e-9));
      expect(bar.statusPerSeat, isTrue);
    });

    testWidgets('the slider turns the bar', (tester) async {
      await addBar(tester);
      tester
          .widget<Slider>(find.byKey(const ValueKey('item-rotation')))
          .onChanged!(30);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('save')));
      await settle(tester);
      expect(repository.saved!.tables.last.rotation, 30);
    });

    testWidgets('the next bar is called Bar 3', (tester) async {
      await addBar(tester);
      // Wait for "Added Bar 2" to go: in this small window it covers the
      // panel's last item.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await tester.tap(palette('barTable'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('save')));
      await settle(tester);
      expect(repository.saved!.tables.where((t) => t.bar).map((t) => t.label), [
        'Bar 2',
        'Bar 3',
      ]);
    });
  });

  testWidgets('tapping a panel item adds and selects it', (tester) async {
    await openPage(tester);
    await goToStep(tester, 'tableAndSeat');

    await tester.tap(palette('circleTable'));
    await settle(tester);

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
    await settle(tester);

    expect(find.text('Added Plant'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save')));
    await settle(tester);
    final plant = repository.saved!.elements.last as FixtureElement;
    expect((plant.x, plant.y), (20.0, 20.0));
  });

  testWidgets('shows a readable error for a broken plan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FloorPlanPage(repository: _BrokenRepository())),
    );
    await settle(tester);

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
