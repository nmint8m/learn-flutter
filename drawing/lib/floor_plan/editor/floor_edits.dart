import 'dart:math' as math;
import 'dart:ui';

import '../floor_plan.dart';
import 'palette.dart' show nextTableNumber;

/// Points at one item on the floor: a table (by id) or a room & decor
/// element (by its position in [FloorPlan.elements]).
sealed class FloorItemRef {
  const FloorItemRef();
}

final class TableRef extends FloorItemRef {
  const TableRef(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is TableRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class ElementRef extends FloorItemRef {
  const ElementRef(this.index);

  final int index;

  @override
  bool operator ==(Object other) => other is ElementRef && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

/// One side of the room's outline ([FloorPlan.floorOutline]): from corner
/// [index] to the next corner, wrapping around to the first. These are the
/// room's outer walls.
final class OutlineEdgeRef extends FloorItemRef {
  const OutlineEdgeRef(this.index);

  final int index;

  @override
  bool operator ==(Object other) =>
      other is OutlineEdgeRef && other.index == index;

  @override
  int get hashCode => Object.hash(OutlineEdgeRef, index);
}

/// The points of a selected wall, start to end: a wall element's points, or
/// the two corners of an outer wall. Null for anything that isn't a wall.
List<Offset>? wallPoints(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  ElementRef(:final index) => switch (plan.elements[index]) {
    WallElement(:final points) => points,
    _ => null,
  },
  OutlineEdgeRef(:final index) => _edge(plan.floorOutline, index),
  TableRef() => null,
};

List<Offset> _edge(List<Offset> outline, int index) => [
  outline[index],
  outline[(index + 1) % outline.length],
];

/// One end of a wall.
enum WallEnd { start, end }

/// The end of the wall [ref] within [radius] of [at] (floor units), or null
/// if neither end is that close (or [ref] isn't a wall).
WallEnd? wallEndAt(FloorPlan plan, FloorItemRef ref, Offset at, double radius) {
  final points = wallPoints(plan, ref);
  if (points == null) return null;
  final toStart = (at - points.first).distance;
  final toEnd = (at - points.last).distance;
  if (toStart > radius && toEnd > radius) return null;
  return toStart <= toEnd ? WallEnd.start : WallEnd.end;
}

/// [plan] with one end of the wall [ref] moved by [delta] (floor units). The
/// rest of the wall stays put. For an outer wall the end is a corner of the
/// room, so the neighboring outer wall follows it.
FloorPlan moveWallEnd(
  FloorPlan plan,
  FloorItemRef ref,
  WallEnd end,
  Offset delta,
) {
  switch (ref) {
    case ElementRef(:final index):
      if (plan.elements[index] case final WallElement wall) {
        final points = [...wall.points];
        points[end == WallEnd.start ? 0 : points.length - 1] += delta;
        return plan.copyWith(
          elements: [...plan.elements]..[index] = wall.copyWith(points: points),
        );
      }
      return plan;
    case OutlineEdgeRef(:final index):
      final outline = [...plan.floorOutline];
      outline[end == WallEnd.start ? index : (index + 1) % outline.length] +=
          delta;
      return plan.copyWith(outline: outline);
    case TableRef():
      return plan;
  }
}

/// [plan] with that wall end rounded to one decimal ([roundPosition]),
/// e.g. after a drag.
FloorPlan snapWallEnd(FloorPlan plan, FloorItemRef ref, WallEnd end) {
  final points = wallPoints(plan, ref);
  if (points == null) return plan;
  final point = end == WallEnd.start ? points.first : points.last;
  const snap = roundPosition;
  return moveWallEnd(
    plan,
    ref,
    end,
    Offset(snap(point.dx), snap(point.dy)) - point,
  );
}

/// Whether the item has a name that can be edited. Outer walls don't.
bool canRename(FloorItemRef ref) => ref is! OutlineEdgeRef;

/// The item under [point] (floor units), or null. Only tables are found when
/// [tables] is true, and only room & decor elements otherwise. Items added
/// later are on top, so they are checked first.
FloorItemRef? hitTestItem(
  FloorPlan plan,
  Offset point, {
  required bool tables,
}) {
  if (tables) {
    for (final table in plan.tables.reversed) {
      if (_insideShape(
        point,
        table.shape,
        Offset(table.x, table.y),
        Size(table.width, table.height),
        table.rotation,
      )) {
        return TableRef(table.id);
      }
    }
    return null;
  }

  // Fixtures first: they sit on top of the walls.
  for (var i = plan.elements.length - 1; i >= 0; i--) {
    if (plan.elements[i] case final FixtureElement f
        when _insideShape(
          point,
          f.shape,
          Offset(f.x, f.y),
          Size(f.width, f.height),
          f.rotation,
        )) {
      return ElementRef(i);
    }
  }
  for (var i = plan.elements.length - 1; i >= 0; i--) {
    final hit = switch (plan.elements[i]) {
      OpeningElement(:final ends) => _nearSegment(point, ends, 0.6),
      WallElement(:final points) => [
        for (var j = 1; j < points.length; j++) (points[j - 1], points[j]),
      ].any((segment) => _nearSegment(point, segment, 0.4)),
      FixtureElement() => false,
    };
    if (hit) return ElementRef(i);
  }
  // Last, the room's outer walls.
  final outline = plan.floorOutline;
  for (var i = 0; i < outline.length; i++) {
    final [a, b] = _edge(outline, i);
    if (_nearSegment(point, (a, b), 0.4)) return OutlineEdgeRef(i);
  }
  return null;
}

/// [plan] with the item moved by [delta] (floor units).
FloorPlan moveItem(FloorPlan plan, FloorItemRef ref, Offset delta) {
  switch (ref) {
    case TableRef(:final id):
      return plan.copyWith(
        tables: [
          for (final t in plan.tables)
            t.id == id ? t.copyWith(x: t.x + delta.dx, y: t.y + delta.dy) : t,
        ],
      );
    case ElementRef(:final index):
      final moved = switch (plan.elements[index]) {
        final WallElement w => w.copyWith(
          points: [for (final p in w.points) p + delta],
        ),
        final OpeningElement o => o.copyWith(
          x: o.x + delta.dx,
          y: o.y + delta.dy,
        ),
        final FixtureElement f => f.copyWith(
          x: f.x + delta.dx,
          y: f.y + delta.dy,
        ),
      };
      return plan.copyWith(elements: [...plan.elements]..[index] = moved);
    case OutlineEdgeRef(:final index):
      // Moving one outer wall moves its two corners; the walls on either
      // side stretch to follow.
      final outline = [...plan.floorOutline];
      final next = (index + 1) % outline.length;
      outline[index] += delta;
      outline[next] += delta;
      return plan.copyWith(outline: outline);
  }
}

/// [plan] with the item's position rounded to one decimal ([roundPosition]),
/// e.g. after a drag.
FloorPlan snapItem(FloorPlan plan, FloorItemRef ref) {
  // A door or window rounds its position along its wall, so it stays
  // exactly on the wall even when the wall is slanted.
  if (ref case ElementRef(:final index)
      when plan.elements[index] is OpeningElement) {
    final opening = plan.elements[index] as OpeningElement;
    return placeOpening(plan, index, opening.center, round: true);
  }
  final anchor = _anchor(plan, ref);
  const snap = roundPosition;
  return moveItem(plan, ref, Offset(snap(anchor.dx), snap(anchor.dy)) - anchor);
}

/// A side of a rectangular table, for its seats.
enum SeatSide { top, bottom, left, right }

/// The rounded rectangle or rounded square table [ref] points at, or null.
/// These tables have seats side by side and can be rotated from the Edit
/// panel.
FloorTable? sidedTable(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => switch (plan.tableById(id)) {
    final table?
        when table.shape.shape == TableShape.roundedRect && !table.bar =>
      table,
    _ => null,
  },
  _ => null,
};

/// Whether [table] is square (a rounded square table).
bool isSquareTable(FloorTable table) => table.width == table.height;

/// How many seats a side gets when it's switched on: one per side on a
/// square table; two along each long side and one at each end on a
/// rectangle.
int defaultSeatsOnSide(FloorTable table, SeatSide side) => isSquareTable(table)
    ? 1
    : switch (side) {
        SeatSide.top || SeatSide.bottom => 2,
        SeatSide.left || SeatSide.right => 1,
      };

/// The number of seats on [side] of [table].
int seatsOnSide(FloorTable table, SeatSide side) => switch (side) {
  SeatSide.top => table.seatLayout.top,
  SeatSide.bottom => table.seatLayout.bottom,
  SeatSide.left => table.seatLayout.left,
  SeatSide.right => table.seatLayout.right,
};

/// [plan] with [side]'s seats on the table switched on (its earlier
/// number of seats, or [defaultSeatsOnSide]) or off.
FloorPlan setSeatSide(
  FloorPlan plan,
  FloorItemRef ref,
  SeatSide side, {
  required bool included,
}) {
  final table = sidedTable(plan, ref);
  if (table == null) return plan;
  final count = !included
      ? 0
      : seatsOnSide(table, side) > 0
      ? seatsOnSide(table, side)
      : defaultSeatsOnSide(table, side);
  final layout = table.seatLayout;
  final changed = table.copyWith(
    seatLayout: switch (side) {
      SeatSide.top => layout.copyWith(top: count),
      SeatSide.bottom => layout.copyWith(bottom: count),
      SeatSide.left => layout.copyWith(left: count),
      SeatSide.right => layout.copyWith(right: count),
    },
  );
  return plan.copyWith(
    tables: [for (final t in plan.tables) t.id == table.id ? changed : t],
  );
}

/// [plan] with the table turned to [degrees] (clockwise, around its center;
/// kept within 0–360).
FloorPlan rotateTable(FloorPlan plan, FloorItemRef ref, double degrees) {
  if (ref case TableRef(:final id)) {
    final angle = degrees % 360;
    return plan.copyWith(
      tables: [
        for (final t in plan.tables)
          t.id == id ? t.copyWith(rotation: angle) : t,
      ],
    );
  }
  return plan;
}

/// The most seats a bar can have.
const maxBarSeats = 10;

/// Floor units of counter per bar seat (1 m at 0.5 m per unit).
const barUnitsPerSeat = 2.0;

/// The bar [ref] points at, or null.
FloorTable? barTable(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => switch (plan.tableById(id)) {
    final table? when table.bar => table,
    _ => null,
  },
  _ => null,
};

/// [plan] with the bar's seats set to [seats] (1 to [maxBarSeats]), all on
/// one side. The counter grows or shrinks with them, around its center.
FloorPlan setBarSeats(FloorPlan plan, FloorItemRef ref, int seats) {
  final bar = barTable(plan, ref);
  if (bar == null) return plan;
  final n = seats.clamp(1, maxBarSeats);
  final changed = bar.copyWith(
    width: n * barUnitsPerSeat,
    seatLayout: SeatLayout(bottom: n),
  );
  return plan.copyWith(
    tables: [for (final t in plan.tables) t.id == bar.id ? changed : t],
  );
}

/// Outer walls are the room's shape: they can't be duplicated or removed.
bool canDuplicateOrRemove(FloorItemRef ref) => ref is! OutlineEdgeRef;

/// How far a duplicate is placed from the original: right and down, in
/// meters.
const duplicateOffsetMeters = 0.2;

/// [plan] with a copy of the item, [duplicateOffsetMeters] to the right of
/// and below the original (a door or window then sticks to the nearest
/// wall, so it only moves along it). Returns the new plan and the copy, or
/// null for outer walls.
///
/// A copied table gets the next free id and number, like a new table;
/// other items keep their name.
(FloorPlan, FloorItemRef)? duplicateItem(FloorPlan plan, FloorItemRef ref) {
  final shift =
      const Offset(duplicateOffsetMeters, duplicateOffsetMeters) /
      plan.metersPerUnit;
  switch (ref) {
    case TableRef(:final id):
      final table = plan.tableById(id)!;
      final number = nextTableNumber(plan);
      final copy = table.copyWith(
        id: 'T$number',
        label: '$number',
        x: roundPosition(table.x + shift.dx),
        y: roundPosition(table.y + shift.dy),
      );
      return (plan.copyWith(tables: [...plan.tables, copy]), TableRef(copy.id));
    case ElementRef(:final index):
      // Added last, so it's drawn (and found by taps) on top.
      final copyRef = ElementRef(plan.elements.length);
      final withCopy = plan.copyWith(
        elements: [...plan.elements, plan.elements[index]],
      );
      return (snapItem(moveItem(withCopy, copyRef, shift), copyRef), copyRef);
    case OutlineEdgeRef():
      return null;
  }
}

/// [plan] without the item. Outer walls can't be removed (they are the
/// room's shape), so [plan] is returned unchanged for them.
///
/// Removing an element shifts the [ElementRef] index of every element after
/// it, so clear any selection afterwards.
FloorPlan removeItem(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => plan.copyWith(
    tables: [
      for (final t in plan.tables)
        if (t.id != id) t,
    ],
  ),
  ElementRef(:final index) => plan.copyWith(
    elements: [...plan.elements]..removeAt(index),
  ),
  OutlineEdgeRef() => plan,
};

/// The length in meters of a door or window, or null for other items.
double? itemLengthMeters(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  ElementRef(:final index) => switch (plan.elements[index]) {
    DoorElement(:final width) ||
    WindowElement(:final width) => width * plan.metersPerUnit,
    _ => null,
  },
  _ => null,
};

/// [plan] with a door's or window's length set to [meters]. Other items are
/// left unchanged.
FloorPlan resizeItem(FloorPlan plan, FloorItemRef ref, double meters) {
  if (ref case ElementRef(:final index)) {
    final width = meters / plan.metersPerUnit;
    final resized = switch (plan.elements[index]) {
      final DoorElement d => d.copyWith(width: width),
      final WindowElement w => w.copyWith(width: width),
      _ => null,
    };
    if (resized != null) {
      return plan.copyWith(elements: [...plan.elements]..[index] = resized);
    }
  }
  return plan;
}

/// A fixture's size in meters. Round fixtures (plants) have the same width
/// and height: one diameter.
typedef FixtureSize = ({double width, double height, bool round});

/// The size of a fixture, in meters; null for other items.
FixtureSize? itemSizeMeters(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  ElementRef(:final index) => switch (plan.elements[index]) {
    FixtureElement(:final width, :final height, :final shape) => (
      width: width * plan.metersPerUnit,
      height: height * plan.metersPerUnit,
      round: shape.shape == TableShape.circle,
    ),
    _ => null,
  },
  _ => null,
};

/// [plan] with a fixture's width and/or height set, in meters. It keeps its
/// center. A round fixture keeps its width and height equal. Other items are
/// left unchanged.
FloorPlan resizeFixture(
  FloorPlan plan,
  FloorItemRef ref, {
  double? width,
  double? height,
}) {
  if (ref case ElementRef(:final index)) {
    if (plan.elements[index] case final FixtureElement f) {
      double? units(double? meters) =>
          meters == null ? null : meters / plan.metersPerUnit;
      var w = units(width);
      var h = units(height);
      if (f.shape.shape == TableShape.circle) {
        w = h = w ?? h;
      }
      return plan.copyWith(
        elements: [...plan.elements]..[index] = f.copyWith(width: w, height: h),
      );
    }
  }
  return plan;
}

/// Meters as people read them: "1.5 m", "0.85 m".
String formatMeters(double meters) {
  final rounded = (meters * 100).roundToDouble() / 100;
  return '${rounded == rounded.roundToDouble() ? rounded.toInt() : rounded} m';
}

/// [plan] with the item's name (label) changed.
FloorPlan renameItem(FloorPlan plan, FloorItemRef ref, String name) {
  switch (ref) {
    case TableRef(:final id):
      return plan.copyWith(
        tables: [
          for (final t in plan.tables) t.id == id ? t.copyWith(label: name) : t,
        ],
      );
    case ElementRef(:final index):
      final renamed = switch (plan.elements[index]) {
        final WallElement w => w.copyWith(label: name),
        final DoorElement d => d.copyWith(label: name),
        final WindowElement w => w.copyWith(label: name),
        final FixtureElement f => f.copyWith(label: name),
      };
      return plan.copyWith(elements: [...plan.elements]..[index] = renamed);
    case OutlineEdgeRef():
      return plan; // Outer walls have no name.
  }
}

/// The item's current name, or '' if it has none.
String itemName(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => plan.tableById(id)?.label ?? '',
  ElementRef(:final index) => plan.elements[index].label ?? '',
  OutlineEdgeRef() => '',
};

/// What kind of item it is, e.g. "Table · circle" or "Window". Walls include
/// their start and end points, e.g. "Wall · (30, 0) → (40, 10)".
String itemKind(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => switch (plan.tableById(id)) {
    final t? when t.bar => 'Bar · ${t.seats.length} seats',
    final t => 'Table · ${t?.shape.shape.name}',
  },
  OutlineEdgeRef() => 'Outer wall · ${_fromTo(wallPoints(plan, ref)!)}',
  ElementRef(:final index) => switch (plan.elements[index]) {
    WallElement(:final points) => 'Wall · ${_fromTo(points)}',
    DoorElement(:final width) =>
      'Door · ${formatMeters(width * plan.metersPerUnit)}',
    WindowElement(:final width) =>
      'Window · ${formatMeters(width * plan.metersPerUnit)}',
    FixtureElement(:final shape, :final width, :final height) =>
      shape.shape == TableShape.circle
          ? 'Plant / round fixture · ⌀ ${formatMeters(width * plan.metersPerUnit)}'
          : 'Fixture · ${_meters(width * plan.metersPerUnit)} × '
                '${formatMeters(height * plan.metersPerUnit)}',
  },
};

/// Whether [ref] still points at something in [plan].
bool itemExists(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => plan.tableById(id) != null,
  ElementRef(:final index) => index < plan.elements.length,
  OutlineEdgeRef(:final index) => index < plan.floorOutline.length,
};

/// [formatMeters] without the unit: "4.8".
String _meters(double meters) => formatMeters(meters).replaceAll(' m', '');

/// A point as people read it: "(30, 0)" or "(12.5, 3)".
String formatPoint(Offset p) => '(${_short(p.dx)}, ${_short(p.dy)})';

String _short(double v) {
  final rounded = roundPosition(v);
  return rounded == rounded.roundToDouble() ? '${rounded.toInt()}' : '$rounded';
}

String _fromTo(List<Offset> points) =>
    '${formatPoint(points.first)} → ${formatPoint(points.last)}';

/// The point that is snapped to the grid: the center, or a wall's first
/// point.
Offset _anchor(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => () {
    final t = plan.tableById(id)!;
    return Offset(t.x, t.y);
  }(),
  ElementRef(:final index) => switch (plan.elements[index]) {
    WallElement(:final points) => points.first,
    DoorElement(:final x, :final y) => Offset(x, y),
    WindowElement(:final x, :final y) => Offset(x, y),
    FixtureElement(:final x, :final y) => Offset(x, y),
  },
  OutlineEdgeRef(:final index) => plan.floorOutline[index],
};

bool _insideShape(
  Offset point,
  ShapeSpec shape,
  Offset center,
  Size size,
  double rotationDegrees,
) {
  // Turn the point back by the item's rotation, so the shape can be checked
  // unrotated around (0, 0).
  final angle = -rotationDegrees * math.pi / 180;
  final d = point - center;
  final local = Offset(
    d.dx * math.cos(angle) - d.dy * math.sin(angle),
    d.dx * math.sin(angle) + d.dy * math.cos(angle),
  );
  final rect = Rect.fromCenter(
    center: Offset.zero,
    width: size.width,
    height: size.height,
  );
  return shape.path(rect, 1).contains(local);
}

bool _nearSegment(Offset p, (Offset, Offset) segment, double maxDistance) {
  final (a, b) = segment;
  final ab = b - a;
  final lengthSquared = ab.distanceSquared;
  final t = lengthSquared == 0
      ? 0.0
      : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared).clamp(
          0.0,
          1.0,
        );
  return (p - (a + ab * t)).distance <= maxDistance;
}

// ---------------------------------------------------------------------------
// Walls that doors and windows stick to
// ---------------------------------------------------------------------------

/// One straight piece of wall: an outer wall, or one segment of an inner
/// wall (a bent wall has a segment per bend).
class WallSegment {
  const WallSegment({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
  });

  /// Identifies the segment within the plan, e.g. `outline-2` or
  /// `wall-0-1` (element 0, segment 1). Changes if walls are added or
  /// removed, so don't store it.
  final String id;

  /// For people, e.g. "Outer wall 3 · (40, 0) → (40, 24)".
  final String name;
  final Offset start;
  final Offset end;

  double get length => (end - start).distance;

  /// How far along the segment the point closest to [p] is, from 0 at
  /// [start] to [length] at [end].
  double distanceAlong(Offset p) {
    final d = end - start;
    if (length == 0) return 0;
    final t = ((p - start).dx * d.dx + (p - start).dy * d.dy) / length;
    return t.clamp(0, length);
  }

  /// The point [distance] along the segment from [start].
  Offset pointAt(double distance) =>
      length == 0 ? start : start + (end - start) * (distance / length);

  double distanceTo(Offset p) => (p - pointAt(distanceAlong(p))).distance;

  /// The segment's direction, in degrees, folded into 0 ≤ angle < 180.
  double get angle => normalizeAngle(
    math.atan2(end.dy - start.dy, end.dx - start.dx) * 180 / math.pi,
  );
}

/// Every straight piece of wall in [plan]: the outer walls first, then the
/// inner walls, in the order they're listed in the file.
List<WallSegment> wallSegments(FloorPlan plan) {
  final outline = plan.floorOutline;
  return [
    for (var i = 0; i < outline.length; i++)
      WallSegment(
        id: 'outline-$i',
        name: 'Outer wall ${i + 1} · ${_fromTo(_edge(outline, i))}',
        start: outline[i],
        end: outline[(i + 1) % outline.length],
      ),
    for (final (index, element) in plan.elements.indexed)
      if (element case WallElement(:final points, :final label))
        for (var j = 1; j < points.length; j++)
          WallSegment(
            id: 'wall-$index-${j - 1}',
            name:
                '${label ?? 'Wall'}'
                '${points.length > 2 ? ' (part $j)' : ''}'
                ' · ${_fromTo([points[j - 1], points[j]])}',
            start: points[j - 1],
            end: points[j],
          ),
  ];
}

/// The wall segment closest to [point], or null if there are no walls.
WallSegment? nearestWall(FloorPlan plan, Offset point) {
  WallSegment? best;
  var bestDistance = double.infinity;
  for (final segment in wallSegments(plan)) {
    final d = segment.distanceTo(point);
    if (d < bestDistance) {
      best = segment;
      bestDistance = d;
    }
  }
  return best;
}

/// The wall the door or window at [index] sits on (the nearest one).
WallSegment? openingWall(FloorPlan plan, int index) {
  final opening = plan.elements[index];
  return opening is OpeningElement ? nearestWall(plan, opening.center) : null;
}

/// [plan] with the door or window at [index] put on a wall, as close to
/// [near] as it fits: on [wall] if given, otherwise on the wall nearest to
/// [near]. It turns to lie along the wall, and is kept fully on the wall
/// when the wall is long enough. [round] rounds its position along the wall
/// to one decimal, e.g. at the end of a drag.
FloorPlan placeOpening(
  FloorPlan plan,
  int index,
  Offset near, {
  WallSegment? wall,
  bool round = false,
}) {
  final opening = plan.elements[index];
  if (opening is! OpeningElement) return plan;
  final segment = wall ?? nearestWall(plan, near);
  if (segment == null) return plan;

  var along = segment.distanceAlong(near);
  if (round) along = roundPosition(along);
  final half = opening.width / 2;
  along = segment.length >= opening.width
      ? along.clamp(half, segment.length - half)
      : segment.length / 2;
  final center = segment.pointAt(along);

  final placed = opening.copyWith(
    x: center.dx,
    y: center.dy,
    angle: segment.angle,
  );
  return plan.copyWith(elements: [...plan.elements]..[index] = placed);
}

/// [plan] with every door and window moved onto its nearest wall. Run after
/// any change, so a door is never left standing alone: e.g. when its wall is
/// moved or removed, or a hand-edited file puts it off a wall.
FloorPlan stickOpenings(FloorPlan plan) {
  var result = plan;
  for (final (index, element) in plan.elements.indexed) {
    if (element is OpeningElement) {
      result = placeOpening(result, index, element.center);
    }
  }
  return result;
}

/// The room, in floor units: the floor's width and height, widened to any
/// outer or inner walls that reach past them.
Rect roomBounds(FloorPlan plan) {
  var bounds = Rect.fromLTWH(0, 0, plan.width, plan.height);
  void addPoint(Offset p) =>
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
  plan.floorOutline.forEach(addPoint);
  for (final element in plan.elements) {
    if (element case WallElement(:final points)) points.forEach(addPoint);
  }
  return bounds;
}

/// A rect around an item; a rotated one gets the circle around it.
Rect _box(Offset center, double width, double height, double rotation) =>
    rotation % 180 == 0
    ? Rect.fromCenter(center: center, width: width, height: height)
    : Rect.fromCircle(
        center: center,
        radius: math.sqrt(width * width + height * height) / 2,
      );

/// Everything drawn on the floor, in floor units: the floor itself plus any
/// walls, doors, fixtures, tables or seats that reach past it.
Rect planContentBounds(FloorPlan plan) {
  var bounds = Rect.fromLTWH(0, 0, plan.width, plan.height);
  void add(Rect r) => bounds = bounds.expandToInclude(r);
  void addPoint(Offset p) =>
      add(Rect.fromCenter(center: p, width: 0, height: 0));

  plan.floorOutline.forEach(addPoint);
  for (final element in plan.elements) {
    switch (element) {
      case WallElement(:final points):
        points.forEach(addPoint);
      case OpeningElement(:final ends):
        addPoint(ends.$1);
        addPoint(ends.$2);
      case FixtureElement(
        :final x,
        :final y,
        :final width,
        :final height,
        :final rotation,
      ):
        add(_box(Offset(x, y), width, height, rotation));
    }
  }
  for (final t in plan.tables) {
    final center = Offset(t.x, t.y);
    add(_box(center, t.width, t.height, t.rotation));
    for (final seat in t.seats) {
      final at = t.rotation == 0
          ? seat.offset
          : Offset.fromDirection(
              seat.offset.direction + t.rotation * math.pi / 180,
              seat.offset.distance,
            );
      add(
        Rect.fromCircle(center: center + at, radius: SeatLayout.seatSize / 2),
      );
    }
  }
  return bounds;
}

// ---------------------------------------------------------------------------
// Rule: tables stay inside the room
// ---------------------------------------------------------------------------

/// How far past a wall a table may poke, in floor units: enough for
/// positions rounded to one decimal.
const _wallTolerance = 0.06;

/// Points around [table]'s edge and its seats, in floor units, turned with
/// the table.
List<Offset> _tableOutline(FloorTable table) {
  final center = Offset(table.x, table.y);
  final turn = table.rotation * math.pi / 180;
  Offset turned(Offset p) => p == Offset.zero
      ? p
      : Offset.fromDirection(p.direction + turn, p.distance);
  final halfW = table.width / 2;
  final halfH = table.height / 2;
  final edge = table.shape.shape == TableShape.circle
      ? [
          for (var i = 0; i < 12; i++)
            Offset.fromDirection(i * math.pi / 6).scale(halfW, halfH),
        ]
      : [
          Offset(-halfW, -halfH),
          Offset(halfW, -halfH),
          Offset(halfW, halfH),
          Offset(-halfW, halfH),
        ];
  const r = SeatLayout.seatSize / 2;
  return [
    for (final p in edge) center + turned(p),
    for (final seat in table.seats)
      for (final d in const [
        Offset(r, 0),
        Offset(-r, 0),
        Offset(0, r),
        Offset(0, -r),
      ])
        center + turned(seat.offset) + d,
  ];
}

bool _insidePolygon(Offset p, List<Offset> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  if (inside) return true;
  // Just outside, within rounding of a wall, still counts.
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    if (_distanceToSegment(p, polygon[j], polygon[i]) <= _wallTolerance) {
      return true;
    }
  }
  return false;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.distanceSquared;
  if (lengthSquared == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).distance;
}

/// Whether [table], with its seats, is inside the room's walls.
bool tableInsideRoom(FloorPlan plan, FloorTable table) {
  final room = plan.floorOutline;
  return _tableOutline(table).every((p) => _insidePolygon(p, room));
}

/// The tables that are (partly) outside the room.
List<FloorTable> tablesOutsideRoom(FloorPlan plan) => [
  for (final t in plan.tables)
    if (!tableInsideRoom(plan, t)) t,
];

/// [moveItem], but a table inside the room stays inside: a move that would
/// take it past a wall slides it along the wall instead, or doesn't happen.
/// A table that is already outside (from an older plan) moves freely, so it
/// can be brought in.
FloorPlan moveItemInsideRoom(FloorPlan plan, FloorItemRef ref, Offset delta) {
  final table = switch (ref) {
    TableRef(:final id) => plan.tableById(id),
    _ => null,
  };
  if (table == null || !tableInsideRoom(plan, table)) {
    return moveItem(plan, ref, delta);
  }
  for (final step in [delta, Offset(delta.dx, 0), Offset(0, delta.dy)]) {
    if (step == Offset.zero) continue;
    final moved = moveItem(plan, ref, step);
    if (tableInsideRoom(plan, moved.tableById(table.id)!)) return moved;
  }
  return plan;
}

/// [plan] with table [id] moved to the nearest spot inside the room, if it
/// isn't inside already (e.g. after being added, dropped or copied). Looks
/// in rings of 0.5 units, up to the room's size; if nowhere fits, the table
/// stays where it is.
FloorPlan placeTableInsideRoom(FloorPlan plan, String id) {
  final table = plan.tableById(id);
  if (table == null || tableInsideRoom(plan, table)) return plan;
  final room = roomBounds(plan);
  final maxRing = (math.max(room.width, room.height) / 0.5).ceil();
  for (var ring = 1; ring <= maxRing; ring++) {
    final r = ring * 0.5;
    // Points around a square ring, nearest (the sides' middles) first.
    final candidates = <Offset>[
      for (var i = -ring; i <= ring; i++) ...[
        Offset(i * 0.5, -r),
        Offset(i * 0.5, r),
        Offset(-r, i * 0.5),
        Offset(r, i * 0.5),
      ],
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    for (final shift in candidates) {
      final at = table.copyWith(
        x: roundPosition(table.x + shift.dx),
        y: roundPosition(table.y + shift.dy),
      );
      if (tableInsideRoom(plan, at)) {
        return plan.copyWith(
          tables: [for (final t in plan.tables) t.id == id ? at : t],
        );
      }
    }
  }
  return plan;
}
