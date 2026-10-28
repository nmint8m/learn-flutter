import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../geometry/geometry_shape.dart';
import 'editor/floor_edits.dart';
import 'editor/palette.dart';
import 'floor_plan.dart';
import 'table_status.dart';

/// Draws a [FloorPlan], scaled to fit the available space, with pinch-to-zoom
/// and panning.
///
/// Layers, bottom to top:
///   1. floor, grid, walls, doors and windows: one [CustomPaint]
///   2. fixtures (kitchen, plants): [GeometryShape]s
///   3. tables and their seats: [GeometryShape]s
///
/// Items don't handle taps themselves: the view reports where the floor was
/// tapped ([onFloorTap], in floor units) and the page decides what was hit.
class FloorPlanView extends StatefulWidget {
  const FloorPlanView({
    super.key,
    required this.plan,
    this.statusOf,
    this.selected,
    this.onFloorTap,
    this.onItemDropped,
    this.onSelectedDrag,
    this.onSelectedDragEnd,
  });

  final FloorPlan plan;

  /// Looks up a table's (or seat's) live status, to color it. Null draws
  /// every table in one neutral color.
  final TableStatus Function(String id)? statusOf;

  /// Drawn highlighted.
  final FloorItemRef? selected;

  /// Called with the tapped point, in floor units. Null ignores taps.
  final ValueChanged<Offset>? onFloorTap;

  /// Called when an item from the design panel is dropped on the floor, with
  /// the drop point in floor units. Null means the floor accepts no drops.
  final void Function(PaletteItem item, Offset at)? onItemDropped;

  /// Move mode: when set, zoom and pan are frozen and dragging anywhere on
  /// the floor reports how far to move the selected item (floor units).
  final ValueChanged<Offset>? onSelectedDrag;
  final VoidCallback? onSelectedDragEnd;

  @override
  State<FloorPlanView> createState() => _FloorPlanViewState();
}

class _FloorPlanViewState extends State<FloorPlanView> {
  /// Where the last move-mode drag update was, to turn positions into steps.
  /// Kept here, not in build: every update rebuilds the view.
  Offset? _lastDrag;

  @override
  Widget build(BuildContext context) {
    final FloorPlanView(
      :plan,
      :statusOf,
      :selected,
      :onFloorTap,
      :onSelectedDrag,
      :onSelectedDragEnd,
    ) = widget;
    final moving = onSelectedDrag != null;
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // How many pixels one floor unit takes, so the whole plan fits.
        final pixelsPerUnit = math.min(
          constraints.maxWidth / plan.width,
          constraints.maxHeight / plan.height,
        );
        final floorSize = Size(
          plan.width * pixelsPerUnit,
          plan.height * pixelsPerUnit,
        );

        // Converts a center + size in floor units to a pixel rect.
        Rect toPixels(double x, double y, double width, double height) =>
            Rect.fromCenter(
              center: Offset(x, y) * pixelsPerUnit,
              width: width * pixelsPerUnit,
              height: height * pixelsPerUnit,
            );

        Offset toUnits(Offset local) => local / pixelsPerUnit;

        final floor = GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Measure moves from where the finger first touched, so the item
          // keeps up with the finger instead of lagging by the drag slop.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: onFloorTap == null
              ? null
              : (details) => onFloorTap(toUnits(details.localPosition)),
          // Only in move mode, so normal drags still pan the floor.
          onPanStart: moving
              ? (details) => _lastDrag = details.localPosition
              : null,
          onPanUpdate: moving
              ? (details) {
                  final previous = _lastDrag ?? details.localPosition;
                  _lastDrag = details.localPosition;
                  onSelectedDrag(toUnits(details.localPosition - previous));
                }
              : null,
          onPanEnd: moving
              ? (_) {
                  _lastDrag = null;
                  onSelectedDragEnd?.call();
                }
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FloorPainter(
                    plan: plan,
                    pixelsPerUnit: pixelsPerUnit,
                    lineColor: colors.onSurface,
                    floorColor: colors.surface,
                    highlightColor: colors.primary,
                    selectedElement: switch (selected) {
                      ElementRef(:final index) => index,
                      _ => null,
                    },
                  ),
                ),
              ),
              for (final (index, element) in plan.elements.indexed)
                if (element case final FixtureElement fixture)
                  _FixtureWidget(
                    fixture: fixture,
                    rect: toPixels(
                      fixture.x,
                      fixture.y,
                      fixture.width,
                      fixture.height,
                    ),
                    pixelsPerUnit: pixelsPerUnit,
                    selected: selected == ElementRef(index),
                  ),
              for (final table in plan.tables)
                _TableWidget(
                  key: ValueKey('table-${table.id}'),
                  table: table,
                  rect: toPixels(table.x, table.y, table.width, table.height),
                  pixelsPerUnit: pixelsPerUnit,
                  statusOf: statusOf,
                  selected: selected == TableRef(table.id),
                ),
            ],
          ),
        );

        return InteractiveViewer(
          // Move mode keeps the current zoom and position.
          panEnabled: !moving,
          scaleEnabled: !moving,
          minScale: 1,
          maxScale: 6,
          boundaryMargin: const EdgeInsets.all(48),
          child: Center(
            child: _dropTarget(
              context,
              pixelsPerUnit,
              SizedBox.fromSize(size: floorSize, child: floor),
            ),
          ),
        );
      },
    );
  }

  /// Wraps the floor so design panel items can be dropped on it.
  Widget _dropTarget(BuildContext context, double pixelsPerUnit, Widget floor) {
    final onDrop = widget.onItemDropped;
    if (onDrop == null) return floor;

    late BuildContext targetContext;
    return DragTarget<PaletteItem>(
      onAcceptWithDetails: (details) {
        // details.offset is the finger's position on screen. globalToLocal
        // also undoes the zoom and pan, so this is right at any zoom level.
        final box = targetContext.findRenderObject()! as RenderBox;
        final local = box.globalToLocal(details.offset);
        onDrop(details.data, local / pixelsPerUnit);
      },
      builder: (context, candidates, rejected) {
        targetContext = context;
        // Outline the floor while an item is dragged over it.
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: candidates.isEmpty
                ? null
                : Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
          ),
          child: floor,
        );
      },
    );
  }
}

/// Paints everything that never reacts to taps, in one pass.
class _FloorPainter extends CustomPainter {
  _FloorPainter({
    required this.plan,
    required this.pixelsPerUnit,
    required this.lineColor,
    required this.floorColor,
    required this.highlightColor,
    this.selectedElement,
  });

  final FloorPlan plan;
  final double pixelsPerUnit;
  final Color lineColor;
  final Color floorColor;
  final Color highlightColor;

  /// Index in [FloorPlan.elements] of a selected wall, door or window, drawn
  /// with a highlight. (Selected fixtures highlight themselves.)
  final int? selectedElement;

  static const _wallThickness = 0.25; // floor units

  @override
  void paint(Canvas canvas, Size size) {
    final ppu = pixelsPerUnit;

    // The room's shape. Outside it (e.g. the gap in a U-shaped room) stays
    // empty: no floor color, no grid.
    final floor = Path()
      ..addPolygon([for (final p in plan.floorOutline) p * ppu], true);
    canvas.drawPath(floor, Paint()..color = floorColor);

    canvas.save();
    canvas.clipPath(floor);
    if (plan.gridSize > 0) {
      final grid = Paint()
        ..color = lineColor.withValues(alpha: 0.06)
        ..strokeWidth = 1;
      for (var x = 0.0; x <= plan.width; x += plan.gridSize) {
        canvas.drawLine(Offset(x * ppu, 0), Offset(x * ppu, size.height), grid);
      }
      for (var y = 0.0; y <= plan.height; y += plan.gridSize) {
        canvas.drawLine(Offset(0, y * ppu), Offset(size.width, y * ppu), grid);
      }
    }
    canvas.restore();

    final wallPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _wallThickness * ppu
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.square;

    // The outer wall follows the room's outline.
    canvas.drawPath(floor, wallPaint);

    for (final element in plan.elements) {
      switch (element) {
        case WallElement(:final points):
          final path = Path()
            ..moveTo(points.first.dx * ppu, points.first.dy * ppu);
          for (final p in points.skip(1)) {
            path.lineTo(p.dx * ppu, p.dy * ppu);
          }
          canvas.drawPath(path, wallPaint);
        case DoorElement() || WindowElement():
          // Doors and windows are painted after all walls, below.
          break;
        case FixtureElement():
          // Fixtures are widgets, drawn on top of this painter.
          break;
      }
    }

    // A window: the wall is replaced by a light pane between two thin lines.
    for (final window in plan.elements.whereType<WindowElement>()) {
      final center = Offset(window.x, window.y) * ppu;
      final half = window.width / 2 * ppu;
      final along = window.vertical ? const Offset(0, 1) : const Offset(1, 0);
      final across = window.vertical ? const Offset(1, 0) : const Offset(0, 1);
      final thickness = _wallThickness * ppu;
      final a = center - along * half;
      final b = center + along * half;

      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFFB3E5FC)
          ..strokeWidth = thickness * 1.6,
      );
      final frame = Paint()
        ..color = lineColor.withValues(alpha: 0.8)
        ..strokeWidth = math.max(1, 0.05 * ppu);
      for (final side in [-1, 1]) {
        final shift = across * (thickness * 0.8 * side);
        canvas.drawLine(a + shift, b + shift, frame);
      }
    }

    // A door is a gap cut into the wall, with a small post at each side.
    for (final door in plan.elements.whereType<DoorElement>()) {
      final center = Offset(door.x, door.y) * ppu;
      final half = door.width / 2 * ppu;
      final along = door.vertical ? const Offset(0, 1) : const Offset(1, 0);
      final across = door.vertical ? const Offset(1, 0) : const Offset(0, 1);
      final a = center - along * half;
      final b = center + along * half;

      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = floorColor
          ..strokeWidth = _wallThickness * ppu * 1.6,
      );
      final post = Paint()
        ..color = lineColor
        ..strokeWidth = math.max(2, 0.08 * ppu);
      final postLength = _wallThickness * ppu;
      for (final end in [a, b]) {
        canvas.drawLine(
          end - across * postLength,
          end + across * postLength,
          post,
        );
      }

      if (door.label case final label?) {
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(color: lineColor, fontSize: 0.5 * ppu),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Next to the opening: above a horizontal door, left of a vertical
        // one.
        final anchor = door.vertical
            ? center + Offset(-0.5 * ppu - text.width / 2, 0)
            : center + Offset(0, -0.9 * ppu);
        text.paint(canvas, anchor - Offset(text.width / 2, text.height / 2));
      }
    }

    _paintSelection(canvas);
  }

  /// A soft, wide band in the highlight color over a selected wall, door or
  /// window.
  void _paintSelection(Canvas canvas) {
    final index = selectedElement;
    if (index == null || index >= plan.elements.length) return;
    final ppu = pixelsPerUnit;
    final paint = Paint()
      ..color = highlightColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _wallThickness * ppu * 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void opening(double x, double y, double width, bool vertical) {
      final center = Offset(x, y) * ppu;
      final half = width / 2 * ppu;
      final along = vertical ? const Offset(0, 1) : const Offset(1, 0);
      canvas.drawLine(center - along * half, center + along * half, paint);
    }

    switch (plan.elements[index]) {
      case WallElement(:final points):
        canvas.drawPath(
          Path()..addPolygon([for (final p in points) p * ppu], false),
          paint,
        );
      case DoorElement(:final x, :final y, :final width, :final vertical):
        opening(x, y, width, vertical);
      case WindowElement(:final x, :final y, :final width, :final vertical):
        opening(x, y, width, vertical);
      case FixtureElement():
        break;
    }
  }

  @override
  bool shouldRepaint(_FloorPainter old) =>
      old.plan != plan ||
      old.pixelsPerUnit != pixelsPerUnit ||
      old.lineColor != lineColor ||
      old.floorColor != floorColor ||
      old.highlightColor != highlightColor ||
      old.selectedElement != selectedElement;
}

/// Places [child] so its center is at [rect]'s center, turned by [degrees].
class _Placed extends StatelessWidget {
  const _Placed({
    required this.rect,
    required this.degrees,
    required this.child,
  });

  final Rect rect;
  final double degrees;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Transform.rotate(angle: degrees * math.pi / 180, child: child),
    );
  }
}

class _FixtureWidget extends StatelessWidget {
  const _FixtureWidget({
    required this.fixture,
    required this.rect,
    required this.pixelsPerUnit,
    required this.selected,
  });

  final FixtureElement fixture;
  final Rect rect;
  final double pixelsPerUnit;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Placed(
      rect: rect,
      degrees: fixture.rotation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GeometryShape(
            size: rect.size,
            pathBuilder: (r) => fixture.shape.path(r, pixelsPerUnit),
            fillColor: fixture.color ?? colors.surfaceContainerHighest,
            borderColor: selected ? colors.primary : colors.outlineVariant,
            borderWidth: selected ? math.max(2, 0.15 * pixelsPerUnit) : 1,
          ),
          if (fixture.label case final label?)
            Text(
              label,
              style: TextStyle(
                fontSize: 0.7 * pixelsPerUnit,
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _TableWidget extends StatelessWidget {
  const _TableWidget({
    super.key,
    required this.table,
    required this.rect,
    required this.pixelsPerUnit,
    required this.statusOf,
    required this.selected,
  });

  final FloorTable table;

  /// The table top, in pixels.
  final Rect rect;
  final double pixelsPerUnit;

  /// Looked up with the table id, or with each seat id when the table has
  /// [FloorTable.statusPerSeat].
  /// Null draws the table in a neutral color.
  final TableStatus Function(String id)? statusOf;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ppu = pixelsPerUnit;
    final colors = Theme.of(context).colorScheme;
    final seatSize = SeatLayout.seatSize * ppu;
    final seats = table.seats;
    final statusOf = this.statusOf;
    final perSeat = statusOf != null && table.statusPerSeat && seats.isNotEmpty;
    final tableStatus = statusOf?.call(table.id);

    // The box must be big enough for the seats around the table too, so
    // grow it by the furthest seat's distance on each side.
    var reachX = rect.width / 2;
    var reachY = rect.height / 2;
    for (final seat in seats) {
      reachX = math.max(reachX, seat.offset.dx.abs() * ppu + seatSize / 2);
      reachY = math.max(reachY, seat.offset.dy.abs() * ppu + seatSize / 2);
    }
    final box = Rect.fromCenter(
      center: rect.center,
      width: reachX * 2,
      height: reachY * 2,
    );
    // Center of the box, in the box's own coordinates.
    final mid = Offset(reachX, reachY);
    final top = Rect.fromCenter(
      center: mid,
      width: rect.width,
      height: rect.height,
    );
    Path topPath(Rect r) => table.shape.path(r, ppu);

    return _Placed(
      rect: box,
      degrees: table.rotation,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Seats: drawn under the table, and not tappable themselves. With a
          // status per seat, each chair shows its own color.
          for (final seat in seats)
            Positioned.fromRect(
              rect: Rect.fromCenter(
                center: mid + seat.offset * ppu,
                width: seatSize,
                height: seatSize,
              ),
              child: IgnorePointer(
                child: GeometryShape(
                  size: Size.square(seatSize),
                  pathBuilder: circlePath,
                  fillColor: perSeat
                      ? statusOf(seat.id).color
                      : colors.surfaceContainerHigh,
                  borderColor: colors.outline,
                  borderWidth: 1,
                ),
              ),
            ),
          // With a status per seat, the table top is split into one colored
          // band per seat, so it's readable even when the chairs are tiny.
          if (perSeat)
            Positioned.fromRect(
              rect: top,
              child: IgnorePointer(
                child: ClipPath(
                  clipper: _PathClipper(topPath),
                  child: _SeatBands(
                    seats: seats,
                    statusOf: statusOf,
                    dividerColor: colors.outline,
                  ),
                ),
              ),
            ),
          // The table itself: fill (unless the bands already cover it) and
          // border.
          Positioned.fromRect(
            rect: top,
            child: GeometryShape(
              size: rect.size,
              pathBuilder: topPath,
              fillColor: perSeat
                  ? Colors.transparent
                  : tableStatus?.color ?? colors.secondaryContainer,
              borderColor: selected ? colors.primary : colors.outline,
              borderWidth: math.max(1, (selected ? 0.15 : 0.06) * ppu),
              semanticLabel: perSeat
                  ? '${table.label}, ${_seatSummary(seats, statusOf)}'
                  : 'Table ${table.label}, ${seats.length} seats'
                        '${tableStatus == null ? '' : ', ${tableStatus.label}'}',
            ),
          ),
          // The label stays upright even if the table is rotated, and lets
          // taps through to the table under it.
          Positioned.fromRect(
            rect: top,
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -table.rotation * math.pi / 180,
                  child: Text(
                    table.label,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 0.6 * ppu,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// e.g. "4 seats: 2 Occupied, 1 Free, 1 Reserved".
  String _seatSummary(
    List<Seat> seats,
    TableStatus Function(String id) statusOf,
  ) {
    final counts = <TableStatus, int>{};
    for (final seat in seats) {
      counts.update(statusOf(seat.id), (n) => n + 1, ifAbsent: () => 1);
    }
    return '${seats.length} seats: '
        '${counts.entries.map((e) => '${e.value} ${e.key.label}').join(', ')}';
  }
}

/// One band per seat across the table top, ordered like the seats from left
/// to right. Meant for counters with the seats along one long side.
class _SeatBands extends StatelessWidget {
  const _SeatBands({
    required this.seats,
    required this.statusOf,
    required this.dividerColor,
  });

  final List<Seat> seats;
  final TableStatus Function(String id) statusOf;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final ordered = [...seats]
      ..sort((a, b) => a.offset.dx.compareTo(b.offset.dx));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) Container(width: 1, color: dividerColor),
          Expanded(child: ColoredBox(color: statusOf(ordered[i].id).color)),
        ],
      ],
    );
  }
}

/// Clips a child to a shape from a path builder, e.g. a rounded table top.
class _PathClipper extends CustomClipper<Path> {
  _PathClipper(this.pathBuilder);

  final Path Function(Rect rect) pathBuilder;

  @override
  Path getClip(Size size) => pathBuilder(Offset.zero & size);

  @override
  bool shouldReclip(_PathClipper oldClipper) => true;
}
