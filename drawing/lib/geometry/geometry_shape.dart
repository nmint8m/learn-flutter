import 'package:flutter/material.dart';

import 'geometry_paths.dart';

export 'geometry_paths.dart';

/// Builds a shape's outline inside the given rect. Any function from
/// `geometry_paths.dart` fits, e.g. `(rect) => semicirclePath(rect, side)`.
typedef GeometryPathBuilder = Path Function(Rect rect);

/// A widget that draws one shape and reacts to taps on it.
///
/// Use one of the named constructors:
///
///     GeometryShape.roundedRect(radius: 24, fillColor: Colors.teal)
///     GeometryShape.semicircle(side: SemicircleSide.top, onTap: () {...})
///     GeometryShape.quarterCircle(corner: QuarterCircleCorner.bottomLeft)
///
/// Taps count only inside the shape itself, not anywhere in its box: tapping
/// the empty corner next to a quarter circle does nothing.
class GeometryShape extends StatefulWidget {
  const GeometryShape({
    super.key,
    required this.pathBuilder,
    this.size = const Size.square(120),
    this.fillColor = Colors.blue,
    this.borderColor = Colors.black,
    this.borderWidth = 2,
    this.pressedFillColor,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  GeometryShape.roundedRect({
    Key? key,
    double radius = 16,
    Size size = const Size(160, 100),
    Color fillColor = Colors.blue,
    Color borderColor = Colors.black,
    double borderWidth = 2,
    Color? pressedFillColor,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    String? semanticLabel,
  }) : this(
         key: key,
         pathBuilder: (rect) => roundedRectPath(rect, radius: radius),
         size: size,
         fillColor: fillColor,
         borderColor: borderColor,
         borderWidth: borderWidth,
         pressedFillColor: pressedFillColor,
         onTap: onTap,
         onLongPress: onLongPress,
         semanticLabel: semanticLabel,
       );

  GeometryShape.semicircle({
    Key? key,
    required SemicircleSide side,
    Size? size,
    Color fillColor = Colors.blue,
    Color borderColor = Colors.black,
    double borderWidth = 2,
    Color? pressedFillColor,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    String? semanticLabel,
  }) : this(
         key: key,
         pathBuilder: (rect) => semicirclePath(rect, side),
         // Default box matches the shape's 2:1 ratio, so there is no empty
         // space around it.
         size:
             size ??
             (side == SemicircleSide.top || side == SemicircleSide.bottom
                 ? const Size(120, 60)
                 : const Size(60, 120)),
         fillColor: fillColor,
         borderColor: borderColor,
         borderWidth: borderWidth,
         pressedFillColor: pressedFillColor,
         onTap: onTap,
         onLongPress: onLongPress,
         semanticLabel: semanticLabel,
       );

  GeometryShape.quarterCircle({
    Key? key,
    required QuarterCircleCorner corner,
    Size size = const Size.square(90),
    Color fillColor = Colors.blue,
    Color borderColor = Colors.black,
    double borderWidth = 2,
    Color? pressedFillColor,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    String? semanticLabel,
  }) : this(
         key: key,
         pathBuilder: (rect) => quarterCirclePath(rect, corner),
         size: size,
         fillColor: fillColor,
         borderColor: borderColor,
         borderWidth: borderWidth,
         pressedFillColor: pressedFillColor,
         onTap: onTap,
         onLongPress: onLongPress,
         semanticLabel: semanticLabel,
       );

  final GeometryPathBuilder pathBuilder;
  final Size size;

  /// The inside of the shape.
  final Color fillColor;

  /// The outline. Set [borderWidth] to 0 for no border.
  final Color borderColor;
  final double borderWidth;

  /// The fill while a finger is down on the shape. Defaults to [fillColor]
  /// slightly darkened. Only used when [onTap] or [onLongPress] is set.
  final Color? pressedFillColor;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Read by screen readers, e.g. "Top semicircle".
  final String? semanticLabel;

  @override
  State<GeometryShape> createState() => _GeometryShapeState();
}

class _GeometryShapeState extends State<GeometryShape> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final fill = _pressed
        ? widget.pressedFillColor ??
              Color.lerp(widget.fillColor, Colors.black, 0.25)!
        : widget.fillColor;

    Widget child = LayoutBuilder(
      builder: (context, constraints) {
        // The size the CustomPaint will really get, if the parent is too small
        // for widget.size. The painter needs it for hit testing.
        final size = constraints.constrain(widget.size);
        return CustomPaint(
          size: size,
          painter: GeometryPainter(
            pathBuilder: widget.pathBuilder,
            size: size,
            fillColor: fill,
            borderColor: widget.borderColor,
            borderWidth: widget.borderWidth,
          ),
        );
      },
    );

    if (_interactive) {
      // GestureDetector asks the CustomPaint whether a touch hits it, and
      // GeometryPainter.hitTest answers "only inside the path". So taps on
      // the empty part of the box are ignored.
      child = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: child,
        ),
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      button: _interactive,
      onTap: widget.onTap,
      child: child,
    );
  }
}

/// Paints a shape from a [GeometryPathBuilder]: fill first, then border.
class GeometryPainter extends CustomPainter {
  GeometryPainter({
    required this.pathBuilder,
    required this.size,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
  });

  final GeometryPathBuilder pathBuilder;

  /// The painted size. [hitTest] isn't given a size, so it uses this one.
  final Size size;

  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  /// A border is drawn centered on the outline: half inside, half outside.
  /// Shrinking the rect by half the border width keeps the outer half inside
  /// the widget, so it isn't cut off at the edges.
  Path _pathFor(Size size) =>
      pathBuilder((Offset.zero & size).deflate(borderWidth / 2));

  @override
  void paint(Canvas canvas, Size size) {
    final path = _pathFor(size);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fillColor
        ..isAntiAlias = true,
    );

    if (borderWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = borderColor
          ..strokeWidth = borderWidth
          // Round joins keep the corners where a straight line meets the
          // curve from looking spiky with thick borders.
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }
  }

  /// Only touches inside the shape count as hits.
  @override
  bool hitTest(Offset position) => _pathFor(size).contains(position);

  @override
  bool shouldRepaint(GeometryPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.size != size ||
      // The named constructors create a new builder function on every
      // rebuild, so this is usually true. Repainting one path is cheap.
      oldDelegate.pathBuilder != pathBuilder;
}
