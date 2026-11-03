import 'dart:io';

import 'package:drawing/floor_plan/editor/floor_edits.dart' show TableRef;
import 'package:drawing/floor_plan/floor_plan.dart';
import 'package:drawing/floor_plan/floor_plan_view.dart';
import 'package:drawing/geometry/geometry_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plan = FloorPlan.parse(
    File('test/fixtures/main_floor.json').readAsStringSync(),
  );

  /// The table top's outline: the shape labelled "Table <label>, ...".
  GeometryShape outline(WidgetTester tester, String id) =>
      tester.widget<GeometryShape>(
        find.descendant(
          of: find.byKey(ValueKey('table-$id')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is GeometryShape &&
                (w.semanticLabel?.startsWith('Table ') ?? false),
          ),
        ),
      );

  Future<void> show(
    WidgetTester tester, {
    Set<String> linkedTableIds = const {},
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FloorPlanView(
          plan: plan,
          selected: const TableRef('T1'),
          linkedTableIds: linkedTableIds,
        ),
      ),
    ),
  );

  testWidgets('a grouped table is bolder, its group lighter', (tester) async {
    await show(tester);
    final alone = outline(tester, 'T1').borderWidth;
    final plain = outline(tester, 'T2').borderWidth;

    await show(tester, linkedTableIds: {'T2'});
    final selected = outline(tester, 'T1');
    final linked = outline(tester, 'T2');
    final other = outline(tester, 'T3');

    // Selected: bolder than when it's not in a group.
    expect(selected.borderWidth, greaterThan(alone));
    // Linked: thicker than a plain table, thinner than the selected one,
    // and a lighter shade of the same color.
    expect(linked.borderWidth, greaterThan(plain));
    expect(linked.borderWidth, lessThan(selected.borderWidth));
    expect(linked.borderColor.a, lessThan(selected.borderColor.a));
    expect(linked.borderColor.withValues(alpha: 1), selected.borderColor);
    // Others: unchanged.
    expect(other.borderWidth, plain);
  });

  testWidgets('a pale circle sits under the group, around its tables', (
    tester,
  ) async {
    final circle = find.byKey(const ValueKey('table-group-circle'));
    await show(tester);
    expect(circle, findsNothing);

    await show(tester, linkedTableIds: {'T2'});
    expect(circle, findsOneWidget);
    final box = tester.getRect(circle);
    final center = box.center;
    for (final id in ['T1', 'T2']) {
      final table = tester.getRect(find.byKey(ValueKey('table-$id')));
      for (final corner in [
        table.topLeft,
        table.topRight,
        table.bottomLeft,
        table.bottomRight,
      ]) {
        expect((corner - center).distance, lessThan(box.width / 2));
      }
    }

    // Drawn before (under) the tables.
    final stack = find.ancestor(of: circle, matching: find.byType(Stack)).first;
    final children = tester.widget<Stack>(stack).children;
    final circleAt = children.indexWhere(
      (c) => find
          .descendant(of: find.byWidget(c), matching: circle)
          .evaluate()
          .isNotEmpty,
    );
    final tableAt = children.indexWhere(
      (c) => c.key == const ValueKey('table-T1'),
    );
    expect(circleAt, lessThan(tableAt));
  });

  testWidgets('a pale circle sits under each table of the group', (
    tester,
  ) async {
    await show(tester);
    expect(find.byKey(const ValueKey('group-circle-T1')), findsNothing);

    await show(tester, linkedTableIds: {'T2'});
    expect(find.byKey(const ValueKey('group-circle-T1')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-circle-T2')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-circle-T3')), findsNothing);

    // Centered on the table, and big enough for it and its seats.
    final circle = tester.getRect(
      find.byKey(const ValueKey('group-circle-T2')),
    );
    final table = tester.getRect(find.byKey(const ValueKey('table-T2')));
    expect(circle.center.dx, closeTo(table.center.dx, 0.5));
    expect(circle.center.dy, closeTo(table.center.dy, 0.5));
    expect(circle.width, greaterThan(table.longestSide));
  });
}
