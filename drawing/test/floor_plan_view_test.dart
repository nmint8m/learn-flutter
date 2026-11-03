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
}
