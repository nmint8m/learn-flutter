import 'dart:io';

import 'package:drawing/floor_plan/floor_map_library.dart';
import 'package:drawing/floor_plan/floor_maps_page.dart';
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:flutter/gestures.dart'
    show kDoubleTapMinTime, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps the maps in memory instead of files.
class _MemoryLibrary implements FloorMapLibrary {
  _MemoryLibrary(this.maps);

  List<FloorMap> maps;
  final plans = <String, FloorPlan>{};

  @override
  Future<List<FloorMap>> load() async => [
    for (final m in maps) m.copyWith(plan: plans[m.id] ?? m.plan),
  ];

  @override
  Future<void> saveList(List<FloorMap> maps) async => this.maps = maps;

  @override
  Future<String> savePlan(String id, FloorPlan plan) async {
    plans[id] = plan;
    return 'memory';
  }

  @override
  Future<void> removePlan(String id) async => plans.remove(id);
}

void main() {
  final plan = FloorPlan.parse(
    File('test/fixtures/main_floor.json').readAsStringSync(),
  );
  final seats = plan.tables.fold(0, (sum, t) => sum + t.seats.length);
  late _MemoryLibrary library;

  setUp(
    () => library = _MemoryLibrary([
      FloorMap(id: 'a', name: 'Main floor', plan: plan),
      FloorMap(id: 'b', name: 'Terrace', enabled: false, plan: plan),
    ]),
  );

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: FloorMapsPage(library: library)));
    await tester.pumpAndSettle();
  }

  Future<void> openOptions(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('floor-map-$id')));
    // A single tap only counts once the double-tap window has passed.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
  }

  Future<void> doubleTap(WidgetTester tester, String id) async {
    final card = find.byKey(ValueKey('floor-map-$id'));
    await tester.tap(card);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.byKey(ValueKey('map-option-$option')));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every map with its name, tables and seats', (
    tester,
  ) async {
    await openPage(tester);

    expect(find.text('All Floor plan'), findsOneWidget);
    expect(find.text('Main floor'), findsOneWidget);
    expect(find.text('Terrace'), findsOneWidget);
    expect(find.text('${plan.tables.length} tables'), findsNWidgets(2));
    expect(find.text('$seats seats'), findsNWidgets(2));
    expect(find.text('Disabled'), findsOneWidget);
  });

  testWidgets('a tap floats Configure, Edit, Duplicate and Remove', (
    tester,
  ) async {
    await openPage(tester);
    await openOptions(tester, 'a');

    for (final option in ['configure', 'edit', 'duplicate', 'remove']) {
      expect(find.byKey(ValueKey('map-option-$option')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('map-option-viewOnly')), findsNothing);

    // Tapping outside closes it.
    await tester.tapAt(const Offset(5, 810));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-options')), findsNothing);
  });

  testWidgets('a disabled map offers View only in place of Edit', (
    tester,
  ) async {
    await openPage(tester);
    await openOptions(tester, 'b');

    expect(find.byKey(const ValueKey('map-option-viewOnly')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-option-edit')), findsNothing);
  });

  testWidgets('Configure renames and disables a map', (tester) async {
    await openPage(tester);
    await openOptions(tester, 'a');
    await choose(tester, 'configure');

    await tester.enterText(find.byKey(const ValueKey('map-name')), 'Ground');
    await tester.tap(find.byKey(const ValueKey('map-enabled')));
    await tester.tap(find.byKey(const ValueKey('save-map-config')));
    await tester.pumpAndSettle();

    expect(find.text('Ground'), findsOneWidget);
    expect(library.maps.first.name, 'Ground');
    expect(library.maps.first.enabled, isFalse);

    await openOptions(tester, 'a');
    expect(find.byKey(const ValueKey('map-option-viewOnly')), findsOneWidget);
  });

  testWidgets('Configure needs a name', (tester) async {
    await openPage(tester);
    await openOptions(tester, 'a');
    await choose(tester, 'configure');

    await tester.enterText(find.byKey(const ValueKey('map-name')), '  ');
    await tester.pump();
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save-map-config')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('Duplicate adds "Copy of" right after the original', (
    tester,
  ) async {
    await openPage(tester);
    await openOptions(tester, 'a');
    await choose(tester, 'duplicate');

    expect(find.text('Copy of Main floor'), findsOneWidget);
    expect(library.maps.map((m) => m.name), [
      'Main floor',
      'Copy of Main floor',
      'Terrace',
    ]);
    expect(library.plans[library.maps[1].id], same(plan));
  });

  testWidgets('Remove asks with ✓ and ✕ first', (tester) async {
    await openPage(tester);
    await openOptions(tester, 'b');
    await choose(tester, 'remove');

    expect(find.byKey(const ValueKey('remove-map-question')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancel-remove-map')));
    await tester.pumpAndSettle();
    expect(find.text('Terrace'), findsOneWidget);

    await openOptions(tester, 'b');
    await choose(tester, 'remove');
    await tester.tap(find.byKey(const ValueKey('confirm-remove-map')));
    await tester.pumpAndSettle();
    expect(find.text('Terrace'), findsNothing);
    expect(library.maps.map((m) => m.id), ['a']);
  });

  testWidgets('Edit opens the floor plan with all 3 steps', (tester) async {
    await openPage(tester);
    await openOptions(tester, 'a');
    await choose(tester, 'edit');

    expect(find.byKey(const ValueKey('save')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('map-title'))).data,
      'Main floor',
    );
    // Starts on step 1, and step 2 can be opened.
    expect(find.text('Room & Decor'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('step-tableAndSeat')));
    await tester.pumpAndSettle();
    expect(find.text('Rectangle'), findsWidgets);
  });

  testWidgets('View only opens on Review, with steps 1 and 2 disabled', (
    tester,
  ) async {
    await openPage(tester);
    await openOptions(tester, 'b');
    await choose(tester, 'viewOnly');

    expect(find.byKey(const ValueKey('save')), findsNothing);
    expect(find.text('Rectangle'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('step-tableAndSeat')));
    await tester.tap(find.byKey(const ValueKey('step-roomAndDecor')));
    await tester.pumpAndSettle();
    // Still on Review: no design panel.
    expect(find.text('Rectangle'), findsNothing);
    expect(find.textContaining("review only"), findsOneWidget);
  });

  testWidgets('a double tap opens an enabled map for editing', (tester) async {
    await openPage(tester);
    await doubleTap(tester, 'a');

    expect(find.byKey(const ValueKey('map-options')), findsNothing);
    expect(find.byKey(const ValueKey('save')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('map-title'))).data,
      'Main floor',
    );
  });

  testWidgets('a double tap opens a disabled map view only', (tester) async {
    await openPage(tester);
    await doubleTap(tester, 'b');

    expect(find.byKey(const ValueKey('map-options')), findsNothing);
    expect(find.byKey(const ValueKey('save')), findsNothing);
    expect(find.textContaining('review only'), findsOneWidget);
  });
}
