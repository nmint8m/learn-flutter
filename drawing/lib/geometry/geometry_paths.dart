import 'dart:math' as math;
import 'dart:ui';

/// Functions that build the outline ([Path]) of each shape inside a [Rect].
///
/// They only describe the shape; they don't paint anything. The same path is
/// used to fill the shape, draw its border, and decide whether a tap landed
/// inside it (see `GeometryPainter`).
///
/// Angles follow Flutter's canvas: 0 points right, and positive angles turn
/// clockwise (because y grows downward). So π/2 points down and -π/2 (or 3π/2)
/// points up.

/// Which half of a full circle to draw. The straight diameter line is on the
/// opposite side:
///
///     top:    ◠ dome on top, flat edge at the bottom
///     bottom: ◡ bowl, flat edge at the top
///     left:   ◖ curve on the left, flat edge on the right
///     right:  ◗ curve on the right, flat edge on the left
enum SemicircleSide { top, bottom, left, right }

/// Which quarter of a full circle to draw. The two straight radius lines meet
/// at the circle's center, in the opposite corner:
///
///     topLeft:     curve in the top-left, square corner at the bottom-right
///     topRight:    curve in the top-right, square corner at the bottom-left
///     bottomLeft:  curve in the bottom-left, square corner at the top-right
///     bottomRight: curve in the bottom-right, square corner at the top-left
enum QuarterCircleCorner { topLeft, topRight, bottomLeft, bottomRight }

/// A rectangle filling [rect], with corners rounded by [radius].
///
/// The radius is capped at half the shorter side, so a large value gives a
/// pill or circle instead of a broken shape.
Path roundedRectPath(Rect rect, {double radius = 16}) {
  final maxRadius = math.min(rect.width, rect.height) / 2;
  final r = radius.clamp(0, maxRadius).toDouble();
  return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
}

/// The largest circle that fits in [rect], centered in it.
Path circlePath(Rect rect) => Path()
  ..addOval(
    Rect.fromCircle(
      center: rect.center,
      radius: math.min(rect.width, rect.height) / 2,
    ),
  );

/// The largest semicircle that fits in [rect], centered in it.
///
/// A real semicircle is twice as wide as it is tall (or the reverse for
/// [SemicircleSide.left]/[SemicircleSide.right]), so if [rect] has a different
/// ratio, there is empty space around the shape.
Path semicirclePath(Rect rect, SemicircleSide side) {
  final Offset center;
  final double radius;
  final double startAngle;

  switch (side) {
    case SemicircleSide.top:
      radius = math.min(rect.width / 2, rect.height);
      // The flat edge sits at the bottom of the shape, so the circle's center
      // is half a radius below the middle of rect.
      center = rect.center.translate(0, radius / 2);
      startAngle = math.pi; // from the left end, sweeping over the top
    case SemicircleSide.bottom:
      radius = math.min(rect.width / 2, rect.height);
      center = rect.center.translate(0, -radius / 2);
      startAngle = 0; // from the right end, sweeping under the bottom
    case SemicircleSide.left:
      radius = math.min(rect.height / 2, rect.width);
      center = rect.center.translate(radius / 2, 0);
      startAngle = math.pi / 2; // from the bottom end, round the left
    case SemicircleSide.right:
      radius = math.min(rect.height / 2, rect.width);
      center = rect.center.translate(-radius / 2, 0);
      startAngle = -math.pi / 2; // from the top end, round the right
  }

  // addArc draws the curve; close() adds the straight diameter line back to
  // the start.
  return Path()
    ..addArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi,
    )
    ..close();
}

/// The largest quarter circle that fits in [rect], centered in it.
Path quarterCirclePath(Rect rect, QuarterCircleCorner corner) {
  final radius = math.min(rect.width, rect.height);
  // The quarter circle fills a radius × radius square.
  final square = Rect.fromCenter(
    center: rect.center,
    width: radius,
    height: radius,
  );

  // The circle's center is the square corner opposite the curve.
  final (Offset center, double startAngle) = switch (corner) {
    QuarterCircleCorner.topLeft => (square.bottomRight, math.pi),
    QuarterCircleCorner.topRight => (square.bottomLeft, -math.pi / 2),
    QuarterCircleCorner.bottomRight => (square.topLeft, 0.0),
    QuarterCircleCorner.bottomLeft => (square.topRight, math.pi / 2),
  };

  // Start at the center, draw a radius line to the arc (arcTo connects with a
  // straight line), draw the curve, then close() draws the second radius line
  // back to the center.
  return Path()
    ..moveTo(center.dx, center.dy)
    ..arcTo(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi / 2,
      false,
    )
    ..close();
}
