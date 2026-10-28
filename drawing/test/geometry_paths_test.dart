import 'dart:ui';

import 'package:drawing/geometry/geometry_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const box = Rect.fromLTWH(0, 0, 100, 100);

  group('semicirclePath', () {
    // In a 100×100 box, each semicircle has radius 50 and fills half the box.
    test('top: dome on top, empty underneath', () {
      final path = semicirclePath(box, SemicircleSide.top);
      expect(path.contains(const Offset(50, 40)), isTrue);
      expect(path.contains(const Offset(50, 90)), isFalse);
      expect(path.getBounds().height, closeTo(50, 0.01));
    });

    test('bottom: bowl at the bottom, empty above', () {
      final path = semicirclePath(box, SemicircleSide.bottom);
      expect(path.contains(const Offset(50, 60)), isTrue);
      expect(path.contains(const Offset(50, 10)), isFalse);
    });

    test('left and right', () {
      final left = semicirclePath(box, SemicircleSide.left);
      final right = semicirclePath(box, SemicircleSide.right);
      expect(left.contains(const Offset(40, 50)), isTrue);
      expect(left.contains(const Offset(90, 50)), isFalse);
      expect(right.contains(const Offset(60, 50)), isTrue);
      expect(right.contains(const Offset(10, 50)), isFalse);
    });

    test('fills a 2:1 box exactly', () {
      final bounds = semicirclePath(
        const Rect.fromLTWH(0, 0, 200, 100),
        SemicircleSide.top,
      ).getBounds();
      expect(bounds.width, closeTo(200, 0.01));
      expect(bounds.height, closeTo(100, 0.01));
    });
  });

  group('quarterCirclePath', () {
    // Radius 100: the curve is in the named corner, the square corner opposite.
    final cases = {
      QuarterCircleCorner.topLeft: (
        squareCorner: const Offset(99, 99),
        emptyCorner: const Offset(2, 2),
      ),
      QuarterCircleCorner.topRight: (
        squareCorner: const Offset(1, 99),
        emptyCorner: const Offset(98, 2),
      ),
      QuarterCircleCorner.bottomLeft: (
        squareCorner: const Offset(99, 1),
        emptyCorner: const Offset(2, 98),
      ),
      QuarterCircleCorner.bottomRight: (
        squareCorner: const Offset(1, 1),
        emptyCorner: const Offset(98, 98),
      ),
    };

    cases.forEach((corner, points) {
      test(
        '${corner.name}: filled at the square corner, empty at the curve',
        () {
          final path = quarterCirclePath(box, corner);
          expect(path.contains(points.squareCorner), isTrue);
          expect(path.contains(points.emptyCorner), isFalse);
        },
      );
    });
  });

  group('roundedRectPath', () {
    test('cuts the corners', () {
      final path = roundedRectPath(box, radius: 30);
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(1, 1)), isFalse);
    });

    test('caps a huge radius at half the shorter side', () {
      final path = roundedRectPath(box, radius: 1000);
      // Becomes a circle: the center is in, the corners are out.
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(10, 10)), isFalse);
      expect(path.getBounds(), box);
    });
  });

  test('roundedRectPath copes with a rect smaller than nothing', () {
    // E.g. a tiny shape deflated by its border.
    final rect = Rect.fromLTRB(0, 0, -0.5, -0.2);
    expect(() => roundedRectPath(rect, radius: 4), returnsNormally);
  });
}
