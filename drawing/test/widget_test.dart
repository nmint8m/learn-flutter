import 'package:drawing/geometry/geometry_shape.dart';
import 'package:drawing/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('tapping inside a shape calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        GeometryShape.quarterCircle(
          key: const Key('shape'),
          corner: QuarterCircleCorner.topLeft,
          size: const Size.square(100),
          onTap: () => taps++,
        ),
      ),
    );

    // The square corner of a top-left quarter is at the bottom-right.
    final box = tester.getRect(find.byKey(const Key('shape')));
    await tester.tapAt(box.bottomRight - const Offset(10, 10));
    expect(taps, 1);
  });

  testWidgets('tapping the empty part of the box does nothing', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        GeometryShape.quarterCircle(
          key: const Key('shape'),
          corner: QuarterCircleCorner.topLeft,
          size: const Size.square(100),
          onTap: () => taps++,
        ),
      ),
    );

    // Outside the curve, but still inside the widget's 100×100 box.
    final box = tester.getRect(find.byKey(const Key('shape')));
    await tester.tapAt(box.topLeft + const Offset(5, 5));
    expect(taps, 0);
  });

  testWidgets('the gallery reports which shape was tapped', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShapeGalleryPage()));

    final shape = find.byKey(const Key('semicircle-top'));
    await tester.ensureVisible(shape);
    await tester.pumpAndSettle();
    // Lower middle of the box: inside the dome.
    final box = tester.getRect(shape);
    await tester.tapAt(Offset(box.center.dx, box.center.dy + 10));
    await tester.pump();

    expect(find.text('Tapped: top semicircle'), findsOneWidget);
  });
}
