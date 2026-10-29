import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../geometry/geometry_shape.dart';
import 'editor/floor_edits.dart';
import 'editor/palette.dart';
import 'floor_plan.dart';
import 'table_status.dart';

/// The zoom and pan of a [FloorPlanView]. Besides pinching, it can zoom in
/// steps around the middle of the view, for zoom buttons.
class FloorViewController extends TransformationController {
  /// 25%: the whole floor at a quarter of the size that fits the view.
  static const minScale = 0.25;
  static const maxScale = 6.0;

  /// The zoom buttons step through these.
  static const levels = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0];

  /// The size of the floor's viewport, set by the view on layout. Step zooms
  /// keep its center in place.
  Size _viewport = Size.zero;

  double get scale => value.getMaxScaleOnAxis();
  bool get canZoomIn => scale < maxScale - 1e-6;
  bool get canZoomOut => scale > minScale + 1e-6;

  /// Zooms to the next level up, e.g. from 100% (or 120% after pinching)
  /// to 150%.
  void zoomIn() => zoomTo(
    levels.firstWhere((l) => l > scale + 1e-6, orElse: () => maxScale),
  );

  /// Zooms to the next level down.
  void zoomOut() =>
      zoomTo(levels.lastWhere((l) => l < scale - 1e-6, orElse: () => minScale));

  /// Everything drawn on the floor, in the view's (unzoomed) pixels. Set by
  /// the view on layout.
  Rect _content = Rect.zero;

  /// Shows the whole floor, fitted to the view: 100%, or less if walls or
  /// items reach past the floor's size.
  void fit() {
    final view = Offset.zero & _viewport;
    if (_content.isEmpty || view.isEmpty) {
      value = Matrix4.identity();
      return;
    }
    final s = math
        .min(view.width / _content.width, view.height / _content.height)
        .clamp(minScale, 1.0);
    final shift = view.center - _content.center * s;
    value = Matrix4.translationValues(
      shift.dx,
      shift.dy,
      0,
    ).multiplied(Matrix4.diagonal3Values(s, s, s));
  }

  /// Zooms to [target] (1 = the floor fits the view) around the middle of
  /// the view.
  void zoomTo(double target) {
    final f = target.clamp(minScale, maxScale) / scale;
    final c = _viewport.center(Offset.zero);
    value = Matrix4.translationValues(c.dx, c.dy, 0)
        .multiplied(Matrix4.diagonal3Values(f, f, f))
        .multiplied(Matrix4.translationValues(-c.dx, -c.dy, 0))
        .multiplied(value);
  }
}

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
    this.onFloorDoubleTap,
    this.onItemDropped,
    this.onSelectedDragStart,
    this.onSelectedDrag,
    this.onSelectedDragEnd,
    this.dimTables = false,
    this.dimRoom = false,
    this.showRulers = false,
    this.controller,
  });

  final FloorPlan plan;

  /// Looks up a table's (or seat's) live status, to color it. Null draws
  /// every table in one neutral color.
  final TableStatus Function(String id)? statusOf;

  /// Drawn highlighted.
  final FloorItemRef? selected;

  /// Called with the tapped point, in floor units. Null ignores taps.
  final ValueChanged<Offset>? onFloorTap;

  /// Called with the double-tapped point, in floor units. While set, a
  /// single tap waits a moment (to see if a second tap follows) before
  /// [onFloorTap] is called.
  final ValueChanged<Offset>? onFloorDoubleTap;

  /// Called when an item from the design panel is dropped on the floor, with
  /// the drop point in floor units. Null means the floor accepts no drops.
  final void Function(PaletteItem item, Offset at)? onItemDropped;

  /// Move mode: when set, zoom and pan are frozen and dragging anywhere on
  /// the floor reports how far to move the selected item (floor units).
  final ValueChanged<Offset>? onSelectedDrag;

  /// Called when a move-mode drag starts, with where (floor units) and how
  /// close to a point counts as touching it (floor units, about a fingertip
  /// at the current zoom). Used to grab a wall's start or end point.
  final void Function(Offset at, double touchRadius)? onSelectedDragStart;
  final VoidCallback? onSelectedDragEnd;

  /// Draws the tables and their seats at 30% opacity, e.g. while designing
  /// the room.
  final bool dimTables;

  /// Draws the room's walls, doors, windows and fixtures at 30% opacity,
  /// e.g. while placing tables. The floor and grid stay as they are.
  final bool dimRoom;

  /// Shows rulers in meters along the top and left edges. They stay in
  /// place while zooming and panning, and their marks follow the floor.
  final bool showRulers;

  /// The zoom and pan, e.g. for zoom buttons outside the view. Null: the view
  /// keeps its own.
  final FloorViewController? controller;

  @override
  State<FloorPlanView> createState() => _FloorPlanViewState();
}

class _FloorPlanViewState extends State<FloorPlanView> {
  /// Where the last move-mode drag update was, to turn positions into steps.
  /// Kept here, not in build: every update rebuilds the view.
  Offset? _lastDrag;

  /// The area the floor was fitted to when Move mode started, kept until it
  /// ends.
  Rect? _moveArea;

  /// Where the current double tap landed, in floor units.
  Offset? _doubleTapAt;

  /// The finger being followed in move mode, so a second finger is ignored.
  int? _dragPointer;

  /// The current zoom and pan. The rulers read it to line up with the floor.
  FloorViewController? _ownTransform;
  FloorViewController get _transform =>
      widget.controller ?? (_ownTransform ??= FloorViewController());

  /// How far the rulers' marks reach past the room on each side, in meters.
  static const _rulerMarginMeters = 3.0;

  /// The opacity of the items the current step isn't about.
  static const _dimmed = 0.3;

  /// Thickness of each ruler, in pixels.
  static const _rulerSize = 24.0;

  @override
  void dispose() {
    _ownTransform?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FloorPlanView(
      :plan,
      :statusOf,
      :selected,
      :onFloorTap,
      :onFloorDoubleTap,
      :onSelectedDragStart,
      :onSelectedDrag,
      :onSelectedDragEnd,
      :dimTables,
      :dimRoom,
      :showRulers,
    ) = widget;
    final moving = onSelectedDrag != null;
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The rulers take a strip on the top and left; the floor gets the rest.
        final ruler = showRulers ? _rulerSize : 0.0;
        final viewport = Size(
          math.max(0, constraints.maxWidth - ruler),
          math.max(0, constraints.maxHeight - ruler),
        );
        _transform._viewport = viewport;

        // The whole room (the floor's width and height, widened to any
        // walls past them), plus a little space around anything drawn
        // outside it, like a table beyond the walls. At 100% all of it fits
        // the view, and taps anywhere on it reach the page.
        final room = roomBounds(plan);
        final bounds = planContentBounds(plan).expandToInclude(room);
        // Ignores rounding-sized overhangs (e.g. a door's end at -1e-16 on
        // the x = 0 wall), which would otherwise change the zoom mid-drag.
        const tolerance = 0.05;
        final pastRoom =
            bounds.left < room.left - tolerance ||
            bounds.top < room.top - tolerance ||
            bounds.right > room.right + tolerance ||
            bounds.bottom > room.bottom + tolerance;
        // Frozen while moving, so the floor doesn't shift or re-zoom under
        // the finger when the item being dragged changes what's drawn.
        final fitted = pastRoom ? bounds.inflate(0.5) : room;
        final Rect area;
        if (moving) {
          area = _moveArea ??= fitted;
        } else {
          area = fitted;
          _moveArea = null;
        }

        // How many pixels one floor unit takes, so [area] fits.
        final pixelsPerUnit = math.min(
          viewport.width / area.width,
          viewport.height / area.height,
        );
        final areaSize = area.size * pixelsPerUnit;
        // Where floor point (0, 0) is, before zoom/pan, with [area]
        // centered.
        final floorOrigin =
            Offset(
              (viewport.width - areaSize.width) / 2,
              (viewport.height - areaSize.height) / 2,
            ) -
            area.topLeft * pixelsPerUnit;
        _transform._content =
            floorOrigin + area.topLeft * pixelsPerUnit & areaSize;

        // Converts a center + size in floor units to a pixel rect.
        Rect toPixels(double x, double y, double width, double height) =>
            Rect.fromCenter(
              center: Offset(x, y) * pixelsPerUnit,
              width: width * pixelsPerUnit,
              height: height * pixelsPerUnit,
            );

        // From the tap box's pixels (its top-left is [area]'s top-left) to
        // floor units.
        Offset toUnits(Offset local) => local / pixelsPerUnit + area.topLeft;

        void endDrag() {
          _dragPointer = null;
          _lastDrag = null;
          onSelectedDragEnd?.call();
        }

        final floor = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onFloorTap == null
              ? null
              : (details) => onFloorTap(toUnits(details.localPosition)),
          // Where the second tap of a double tap landed; onDoubleTap itself
          // has no position.
          onDoubleTapDown: onFloorDoubleTap == null
              ? null
              : (details) => _doubleTapAt = toUnits(details.localPosition),
          onDoubleTap: onFloorDoubleTap == null
              ? null
              : () {
                  if (_doubleTapAt case final at?) onFloorDoubleTap(at);
                  _doubleTapAt = null;
                },
          // Move mode reads the finger directly instead of waiting for a
          // drag gesture, which only starts after ~36 pixels: small nudges
          // count too, and the item follows the finger from the first
          // touch. (Zoom, pan and taps are all off in move mode, so nothing
          // else needs these touches.) Only the first finger is followed.
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: moving
                ? (event) {
                    if (_dragPointer != null) return;
                    _dragPointer = event.pointer;
                    _lastDrag = event.localPosition;
                    // About 24 screen pixels, whatever the zoom.
                    final zoom = _transform.value.storage[0];
                    onSelectedDragStart?.call(
                      toUnits(event.localPosition),
                      math.max(1.0, 24 / (pixelsPerUnit * zoom)),
                    );
                  }
                : null,
            onPointerMove: moving
                ? (event) {
                    if (event.pointer != _dragPointer) return;
                    final previous = _lastDrag ?? event.localPosition;
                    _lastDrag = event.localPosition;
                    // A distance, not a position: no offset for where the
                    // tap box starts.
                    onSelectedDrag(
                      (event.localPosition - previous) / pixelsPerUnit,
                    );
                  }
                : null,
            onPointerUp: moving
                ? (event) {
                    if (event.pointer == _dragPointer) endDrag();
                  }
                : null,
            onPointerCancel: moving
                ? (event) {
                    if (event.pointer == _dragPointer) endDrag();
                  }
                : null,
            // Everything below is drawn in floor coordinates, (0, 0) at
            // the floor's corner, so it's shifted to where that is in the
            // tap box ([area]).
            child: Transform.translate(
              offset: -area.topLeft * pixelsPerUnit,
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
                        onHighlightColor: colors.onPrimary,
                        roomOpacity: dimRoom ? _dimmed : 1,
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
                        opacity: dimRoom ? _dimmed : 1,
                      ),
                  for (final table in plan.tables)
                    _TableWidget(
                      key: ValueKey('table-${table.id}'),
                      table: table,
                      rect: toPixels(
                        table.x,
                        table.y,
                        table.width,
                        table.height,
                      ),
                      pixelsPerUnit: pixelsPerUnit,
                      statusOf: statusOf,
                      selected: selected == TableRef(table.id),
                      opacity: dimTables ? _dimmed : 1,
                    ),
                  // On top of everything: the selected wall's highlight and its
                  // start and end labels.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _FloorPainter(
                          plan: plan,
                          pixelsPerUnit: pixelsPerUnit,
                          lineColor: colors.onSurface,
                          floorColor: colors.surface,
                          highlightColor: colors.primary,
                          onHighlightColor: colors.onPrimary,
                          selected: selected,
                          selectionOnly: true,
                          handlesActive: moving,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final viewer = InteractiveViewer(
          transformationController: _transform,
          // Move mode keeps the current zoom and position.
          panEnabled: !moving,
          scaleEnabled: !moving,
          minScale: FloorViewController.minScale,
          maxScale: FloorViewController.maxScale,
          // InteractiveViewer won't zoom out past the point where its
          // boundary fills the view, so the boundary is wide enough to
          // show the floor at minScale; 48 px more for panning past it.
          boundaryMargin: EdgeInsets.symmetric(
            horizontal:
                viewport.width * (1 / FloorViewController.minScale - 1) / 2 +
                48,
            vertical:
                viewport.height * (1 / FloorViewController.minScale - 1) / 2 +
                48,
          ),
          child: SizedBox.fromSize(
            size: viewport,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: floorOrigin.dx + area.left * pixelsPerUnit,
                  top: floorOrigin.dy + area.top * pixelsPerUnit,
                  width: area.width * pixelsPerUnit,
                  height: area.height * pixelsPerUnit,
                  child: _dropTarget(context, toUnits, floor),
                ),
              ],
            ),
          ),
        );
        if (!showRulers) return viewer;

        _RulerPainter rulerPainter(Axis axis) => _RulerPainter(
          axis: axis,
          transform: _transform,
          floorStart: axis == Axis.horizontal ? floorOrigin.dx : floorOrigin.dy,
          range: axis == Axis.horizontal
              ? (room.left, room.right)
              : (room.top, room.bottom),
          margin: _rulerMarginMeters / plan.metersPerUnit,
          pixelsPerUnit: pixelsPerUnit,
          metersPerUnit: plan.metersPerUnit,
          background: colors.surfaceContainer,
          floorBand: colors.surfaceContainerHighest,
          tickColor: colors.onSurfaceVariant,
        );

        return Column(
          children: [
            SizedBox(
              height: ruler,
              child: Row(
                children: [
                  // The corner where the two rulers meet.
                  // The corner says what the marks count: meters.
                  Container(
                    key: const ValueKey('ruler-unit'),
                    width: ruler,
                    color: colors.surfaceContainer,
                    alignment: Alignment.center,
                    child: Text(
                      'm',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      key: const ValueKey('ruler-top'),
                      size: Size.infinite,
                      painter: rulerPainter(Axis.horizontal),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: ruler,
                    child: CustomPaint(
                      key: const ValueKey('ruler-left'),
                      size: Size.infinite,
                      painter: rulerPainter(Axis.vertical),
                    ),
                  ),
                  Expanded(child: ClipRect(child: viewer)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Wraps the floor so design panel items can be dropped on it.
  Widget _dropTarget(
    BuildContext context,
    Offset Function(Offset local) toUnits,
    Widget floor,
  ) {
    final onDrop = widget.onItemDropped;
    if (onDrop == null) return floor;

    late BuildContext targetContext;
    return DragTarget<PaletteItem>(
      onAcceptWithDetails: (details) {
        // details.offset is the finger's position on screen. globalToLocal
        // also undoes the zoom and pan, so this is right at any zoom level.
        final box = targetContext.findRenderObject()! as RenderBox;
        final local = box.globalToLocal(details.offset);
        onDrop(details.data, toUnits(local));
      },
      builder: (context, candidates, rejected) {
        targetContext = context;
        // Outline the room while an item is dragged over it.
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

/// A ruler in floor units along one edge of the floor view.
///
/// It repaints whenever [transform] changes, so its marks stay lined up with
/// the floor while zooming and panning. Marks get denser as you zoom in.
class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.axis,
    required this.transform,
    required this.floorStart,
    required this.range,
    required this.margin,
    required this.pixelsPerUnit,
    required this.metersPerUnit,
    required this.background,
    required this.floorBand,
    required this.tickColor,
  }) : super(repaint: transform);

  final Axis axis;
  final TransformationController transform;

  /// Where the floor starts along this axis, in pixels, before zoom and pan.
  final double floorStart;

  /// What the ruler covers, in floor units: the floor's width (top ruler)
  /// or height (left ruler), widened to any walls past it.
  final (double, double) range;

  /// How far the marks carry on past [range] on both ends, in floor units.
  final double margin;
  final double pixelsPerUnit;

  /// The marks are labelled in meters: a floor unit is this many meters.
  final double metersPerUnit;
  final Color background;
  final Color floorBand;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final horizontal = axis == Axis.horizontal;
    final along = horizontal ? size.width : size.height;
    final across = horizontal ? size.height : size.width;

    // InteractiveViewer only scales and moves, so the matrix is simple:
    // storage[0] is the scale, storage[12] / [13] the x / y offset.
    final m = transform.value.storage;
    final scale = m[0];
    final shift = horizontal ? m[12] : m[13];
    double toScreen(double units) =>
        shift + (floorStart + units * pixelsPerUnit) * scale;
    final pixelsPerShownUnit = pixelsPerUnit * scale;

    // Zoomed in, the floor band and marks reach past the ruler: keep them in.
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    // A lighter band where the room is.
    final (from, to) = range;
    final start = toScreen(from);
    final end = toScreen(to);
    canvas.drawRect(
      horizontal
          ? Rect.fromLTRB(start, 0, end, across)
          : Rect.fromLTRB(0, start, across, end),
      Paint()..color = floorBand,
    );

    // The smallest steps, in meters, that are still far enough apart to
    // read.
    final pixelsPerMeter = pixelsPerShownUnit / metersPerUnit;
    const steps = [0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0];
    final minorMeters = steps.firstWhere(
      (s) => s * pixelsPerMeter >= 6,
      orElse: () => steps.last,
    );
    final labelled = steps.firstWhere(
      (s) => s >= minorMeters && s * pixelsPerMeter >= 36,
      orElse: () => steps.last,
    );
    final minor = minorMeters / metersPerUnit; // In floor units.

    final tick = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    // Marks run past the room by [margin] on both ends.
    final first = ((from - margin) / minor).ceil();
    final last = ((to + margin) / minor).floor();
    for (var i = first; i <= last; i++) {
      final units = i * minor;
      final at = toScreen(units);
      if (at < -1 || at > along + 1) continue;

      final meters = i * minorMeters;
      final isLabelled = _isMultiple(meters, labelled);
      final length = isLabelled ? across * 0.5 : across * 0.25;
      if (horizontal) {
        canvas.drawLine(Offset(at, across - length), Offset(at, across), tick);
      } else {
        canvas.drawLine(Offset(across - length, at), Offset(across, at), tick);
      }

      if (isLabelled) {
        final text = TextPainter(
          text: TextSpan(
            text: _format(meters),
            style: TextStyle(fontSize: 9, color: tickColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, horizontal ? Offset(at + 2, 1) : Offset(1, at + 1));
      }
    }

    // A line where the ruler meets the floor.
    final edge = Paint()
      ..color = tickColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    if (horizontal) {
      canvas.drawLine(
        Offset(0, across - 0.5),
        Offset(along, across - 0.5),
        edge,
      );
    } else {
      canvas.drawLine(
        Offset(across - 0.5, 0),
        Offset(across - 0.5, along),
        edge,
      );
    }
  }

  static bool _isMultiple(double value, double step) {
    final ratio = value / step;
    return (ratio - ratio.roundToDouble()).abs() < 1e-6;
  }

  /// "3", "2.5", "0.25": meters, without float noise.
  static String _format(double meters) {
    final rounded = (meters * 100).roundToDouble() / 100;
    return rounded == rounded.roundToDouble()
        ? '${rounded.toInt()}'
        : '$rounded';
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.axis != axis ||
      old.transform != transform ||
      old.floorStart != floorStart ||
      old.range != range ||
      old.margin != margin ||
      old.pixelsPerUnit != pixelsPerUnit ||
      old.metersPerUnit != metersPerUnit ||
      old.background != background ||
      old.floorBand != floorBand ||
      old.tickColor != tickColor;
}

/// Paints everything that never reacts to taps, in one pass.
class _FloorPainter extends CustomPainter {
  _FloorPainter({
    required this.plan,
    required this.pixelsPerUnit,
    required this.lineColor,
    required this.floorColor,
    required this.highlightColor,
    required this.onHighlightColor,
    this.selected,
    this.selectionOnly = false,
    this.handlesActive = false,
    this.roomOpacity = 1,
  });

  final FloorPlan plan;
  final double pixelsPerUnit;
  final Color lineColor;
  final Color floorColor;
  final Color highlightColor;

  /// Text on top of [highlightColor], e.g. in the wall end labels.
  final Color onHighlightColor;

  /// A selected wall, outer wall, door or window is drawn highlighted.
  /// (Selected fixtures and tables highlight themselves.)
  final FloorItemRef? selected;

  /// True paints only the selection (highlight, wall end markers and
  /// labels). The view uses one painter for the floor at the bottom and a
  /// second with this set on top, so labels are never hidden under fixtures
  /// or tables.
  final bool selectionOnly;

  /// The walls, doors and windows are drawn at this opacity (the floor and
  /// grid aren't).
  final double roomOpacity;

  /// In move mode, wall end markers are drawn bigger: they can be dragged.
  final bool handlesActive;

  static const _wallThickness = 0.25; // floor units

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionOnly) {
      _paintSelection(canvas, size);
      return;
    }
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
      // Across the whole room, which may reach past the plan's width and
      // height; lines stay on multiples of the grid size.
      final area = floor.getBounds().expandToInclude(Offset.zero & size);
      final step = plan.gridSize * ppu;
      for (
        var x = (area.left / step).floorToDouble() * step;
        x <= area.right;
        x += step
      ) {
        canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), grid);
      }
      for (
        var y = (area.top / step).floorToDouble() * step;
        y <= area.bottom;
        y += step
      ) {
        canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
      }
    }
    canvas.restore();

    // Walls, doors and windows, faded together as one layer.
    if (roomOpacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, roomOpacity),
      );
    }

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
      final along = window.along;
      final across = Offset(-along.dy, along.dx);
      final thickness = _wallThickness * ppu;
      final (start, end) = window.ends;
      final a = start * ppu;
      final b = end * ppu;

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
      final center = door.center * ppu;
      final along = door.along;
      final across = Offset(-along.dy, along.dx);
      final (start, end) = door.ends;
      final a = start * ppu;
      final b = end * ppu;

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
        // Next to the opening, on the side facing the middle of the room.
        final toMiddle = size.center(Offset.zero) - center;
        final inward = across.dx * toMiddle.dx + across.dy * toMiddle.dy >= 0
            ? across
            : -across;
        final reach =
            0.4 * ppu +
            (inward.dx.abs() * text.width + inward.dy.abs() * text.height) / 2;
        final anchor = center + inward * reach;
        text.paint(canvas, anchor - Offset(text.width / 2, text.height / 2));
      }
    }
    if (roomOpacity < 1) canvas.restore();
  }

  /// Highlights the selected wall, outer wall, door or window. Walls also get
  /// a marker and a label at their start and end points.
  void _paintSelection(Canvas canvas, Size size) {
    final ref = selected;
    if (ref == null || !itemExists(plan, ref)) return;
    final ppu = pixelsPerUnit;

    final halo = Paint()
      ..color = highlightColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _wallThickness * ppu * 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (wallPoints(plan, ref) case final points?) {
      final path = Path()..addPolygon([for (final p in points) p * ppu], false);
      canvas.drawPath(path, halo);
      // The wall itself, redrawn in the highlight color.
      canvas.drawPath(
        path,
        Paint()
          ..color = highlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _wallThickness * ppu * 1.2
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter,
      );
      // Small dots at any corners in between.
      for (final corner in points.sublist(1, points.length - 1)) {
        canvas.drawCircle(
          corner * ppu,
          math.max(3, 0.15 * ppu),
          Paint()..color = highlightColor,
        );
      }
      _paintEnd(canvas, size, 'Start', points.first, points[1]);
      _paintEnd(canvas, size, 'End', points.last, points[points.length - 2]);
      return;
    }

    if (ref case ElementRef(:final index)) {
      if (plan.elements[index] case final OpeningElement opening) {
        final (a, b) = opening.ends;
        canvas.drawLine(a * ppu, b * ppu, halo);
      }
    }
  }

  /// A marker on a wall end at [point], with a label such as
  /// "Start (30, 0)". The label sits beside the wall, just inside the end
  /// ([neighbor] is the next point along the wall), on the side facing the
  /// middle of the room, and is kept within the floor so it's never cut off.
  void _paintEnd(
    Canvas canvas,
    Size floorSize,
    String name,
    Offset point,
    Offset neighbor,
  ) {
    final ppu = pixelsPerUnit;
    final at = point * ppu;
    final markerRadius = math.max(5.0, 0.3 * ppu) * (handlesActive ? 1.7 : 1);

    canvas.drawCircle(at, markerRadius, Paint()..color = onHighlightColor);
    canvas.drawCircle(
      at,
      markerRadius,
      Paint()
        ..color = highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, 0.08 * ppu),
    );

    final text = TextPainter(
      text: TextSpan(
        text: '$name ${formatPoint(point)}',
        style: TextStyle(
          color: onHighlightColor,
          fontSize: math.max(9, 0.45 * ppu),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final padding = math.max(3.0, 0.15 * ppu);
    final size = Size(text.width + padding * 2, text.height + padding);

    // Along the wall, pointing out of this end.
    final out = point - neighbor;
    final along = out.distance == 0 ? const Offset(1, 0) : out / out.distance;
    // Across the wall, toward the middle of the floor.
    var across = Offset(-along.dy, along.dx);
    final toMiddle = floorSize.center(Offset.zero) - at;
    if (across.dx * toMiddle.dx + across.dy * toMiddle.dy < 0) {
      across = -across;
    }
    // How far the label reaches in a direction from its center.
    double halfExtent(Offset d) =>
        (d.dx.abs() * size.width + d.dy.abs() * size.height) / 2;

    final center =
        at +
        across * (markerRadius + 4 + halfExtent(across)) -
        along * halfExtent(along);
    var box = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );
    // Keep it inside the floor.
    box = box.shift(
      Offset(
        box.left < 0 ? -box.left : math.min(0, floorSize.width - box.right),
        box.top < 0 ? -box.top : math.min(0, floorSize.height - box.bottom),
      ),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(size.height / 2)),
      Paint()..color = highlightColor,
    );
    text.paint(canvas, box.center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_FloorPainter old) =>
      old.plan != plan ||
      old.pixelsPerUnit != pixelsPerUnit ||
      old.lineColor != lineColor ||
      old.floorColor != floorColor ||
      old.highlightColor != highlightColor ||
      old.onHighlightColor != onHighlightColor ||
      old.selected != selected ||
      old.selectionOnly != selectionOnly ||
      old.handlesActive != handlesActive ||
      old.roomOpacity != roomOpacity;
}

/// Places [child] so its center is at [rect]'s center, turned by [degrees].
class _Placed extends StatelessWidget {
  const _Placed({
    required this.rect,
    required this.degrees,
    required this.child,
    this.opacity = 1,
  });

  final Rect rect;
  final double degrees;
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(angle: degrees * math.pi / 180, child: child),
      ),
    );
  }
}

class _FixtureWidget extends StatelessWidget {
  const _FixtureWidget({
    required this.fixture,
    required this.rect,
    required this.pixelsPerUnit,
    required this.selected,
    this.opacity = 1,
  });

  final FixtureElement fixture;
  final Rect rect;
  final double pixelsPerUnit;
  final bool selected;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Placed(
      rect: rect,
      degrees: fixture.rotation,
      opacity: opacity,
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
    this.opacity = 1,
  });

  final FloorTable table;
  final double opacity;

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
      opacity: opacity,
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
          // A bar's counter is split into one stretch per seat.
          if (table.bar && seats.length > 1)
            Positioned.fromRect(
              rect: top,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BarSeparatorPainter(
                    count: seats.length,
                    color: colors.outline,
                    strokeWidth: math.max(1, 0.05 * ppu),
                    inset: 0.25 * ppu,
                  ),
                ),
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

/// Lines across a bar counter, splitting it into [count] equal stretches,
/// one per seat. [inset] keeps them clear of the rounded ends' edges.
class _BarSeparatorPainter extends CustomPainter {
  const _BarSeparatorPainter({
    required this.count,
    required this.color,
    required this.strokeWidth,
    required this.inset,
  });

  final int count;
  final Color color;
  final double strokeWidth;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    final top = math.min(inset, size.height / 4);
    for (var i = 1; i < count; i++) {
      final x = size.width * i / count;
      canvas.drawLine(Offset(x, top), Offset(x, size.height - top), paint);
    }
  }

  @override
  bool shouldRepaint(_BarSeparatorPainter old) =>
      old.count != count ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.inset != inset;
}
