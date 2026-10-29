import 'dart:math' as math;
import 'dart:ui';

import '../../geometry/geometry_paths.dart' show QuarterCircleCorner;
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

/// Whether [table] is a square table ([FloorTable.square]).
bool isSquareTable(FloorTable table) => table.square;

/// The most seats a rectangle table can have along each long side (top and
/// bottom) and at each end (left and right). Square tables have one a side.
const maxSeatsPerLongSide = 4;
const maxSeatsPerEnd = 2;

/// The fewest seats a rectangle table can have along each long side and at
/// each end. The long sides always have more seats than the ends.
const minSeatsPerLongSide = 2;
const minSeatsPerEnd = 1;

bool _isLongSide(SeatSide side) =>
    side == SeatSide.top || side == SeatSide.bottom;

SeatSide _opposite(SeatSide side) => switch (side) {
  SeatSide.top => SeatSide.bottom,
  SeatSide.bottom => SeatSide.top,
  SeatSide.left => SeatSide.right,
  SeatSide.right => SeatSide.left,
};

/// How many seats a side gets when it's switched on: one per side on a
/// square table; on a rectangle, as many as the opposite side, or two along
/// a long side and one at an end.
int defaultSeatsOnSide(FloorTable table, SeatSide side) {
  if (isSquareTable(table)) return 1;
  final opposite = seatsOnSide(table, _opposite(side));
  if (opposite > 0) return opposite;
  return _isLongSide(side) ? 2 : 1;
}

/// The seats on each long side and at each end of a rectangle table: the
/// larger of the two sides (one may be switched off).
({int long, int ends}) rectangleSeats(FloorTable table) => (
  long: math.max(table.seatLayout.top, table.seatLayout.bottom),
  ends: math.max(table.seatLayout.left, table.seatLayout.right),
);

/// [table] sized by the plan's settings: a square table's side is
/// [FloorPlan.squareSeatWidth]; a rectangle follows
/// [FloorPlan.rectSeatWidth]'s formula; a circle with 4, 6, 8 or 10 seats
/// is twice that count's [FloorPlan.circleRadii] across; a quarter circle
/// with 1, 2 or 3 seats gets that count's [FloorPlan.quarterCircleRadii]
/// and its seats spread along the curve. Bars and other tables are returned
/// as they are.
FloorTable sizeTable(FloorPlan plan, FloorTable table) {
  final mpu = plan.metersPerUnit;
  if (table.shape.shape == TableShape.quarterCircle) {
    if (!isSizedQuarterCircleTable(table)) return table;
    final seats = table.seatLayout.custom.length;
    final radius = plan.quarterCircleRadii[seats]! / mpu;
    return table.copyWith(
      width: radius,
      height: radius,
      seatLayout: SeatLayout(
        custom: quarterCircleSeats(table.shape.corner!, radius, seats),
      ),
    );
  }
  if (table.shape.shape == TableShape.circle) {
    if (!isSizedCircleTable(table)) return table;
    final diameter = 2 * plan.circleRadii[table.seatLayout.around]! / mpu;
    return table.copyWith(width: diameter, height: diameter);
  }
  if (table.bar || table.shape.shape != TableShape.roundedRect) return table;
  if (isSquareTable(table)) {
    final side = plan.squareSeatWidth / mpu;
    return table.copyWith(width: side, height: side);
  }
  final (:long, :ends) = rectangleSeats(table);
  final buffer = 2 * plan.rectBuffer;
  final across = math.max(
    ends * plan.rectSeatWidth + buffer,
    2 * plan.rectSeatDepth + FloorPlan.rectMinWidthExtra,
  );
  // At least one seat's width along, so a table without long-side seats
  // still has a length; a buffer before, between and after the seats.
  final seats = math.max(long, 1);
  final along = seats * plan.rectSeatWidth + (seats + 1) * plan.rectBuffer;
  // The table's width (x) runs along the long sides; its height across.
  return table.copyWith(width: along / mpu, height: across / mpu);
}

/// [plan] with table [id] sized by [sizeTable]. If it was inside the room,
/// it's nudged back in should it now poke through a wall.
FloorPlan _resizeTable(FloorPlan before, FloorPlan plan, String id) {
  final sized = plan.copyWith(
    tables: [for (final t in plan.tables) t.id == id ? sizeTable(plan, t) : t],
  );
  final was = before.tableById(id);
  return was != null && tableInsideRoom(before, was)
      ? placeTableInsideRoom(sized, id)
      : sized;
}

/// [plan] with a rectangle table's seats set: [long] on each long side
/// ([minSeatsPerLongSide] to [maxSeatsPerLongSide]) and [ends] at each end
/// ([minSeatsPerEnd] to [maxSeatsPerEnd]). The long sides must end up with
/// more seats than the ends, or nothing changes. Sides that are switched off
/// stay off. The table is resized to fit.
FloorPlan setRectangleSeats(
  FloorPlan plan,
  FloorItemRef ref, {
  int? long,
  int? ends,
}) {
  final table = sidedTable(plan, ref);
  if (table == null || isSquareTable(table)) return plan;
  final current = rectangleSeats(table);
  final l = (long ?? (current.long > 0 ? current.long : minSeatsPerLongSide))
      .clamp(minSeatsPerLongSide, maxSeatsPerLongSide);
  final e = (ends ?? (current.ends > 0 ? current.ends : minSeatsPerEnd)).clamp(
    minSeatsPerEnd,
    maxSeatsPerEnd,
  );
  if (l <= e) return plan;
  final layout = table.seatLayout;
  int keep(int now, int n) => now == 0 ? 0 : n;
  final changed = table.copyWith(
    seatLayout: layout.copyWith(
      top: keep(layout.top, l),
      bottom: keep(layout.bottom, l),
      left: keep(layout.left, e),
      right: keep(layout.right, e),
    ),
  );
  final next = plan.copyWith(
    tables: [for (final t in plan.tables) t.id == table.id ? changed : t],
  );
  return _resizeTable(plan, next, table.id);
}

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
  final next = plan.copyWith(
    tables: [for (final t in plan.tables) t.id == table.id ? changed : t],
  );
  // A rectangle's size follows its seats.
  return isSquareTable(table) ? next : _resizeTable(plan, next, table.id);
}

/// [plan] with the table or fixture turned to [degrees] (clockwise, around
/// its center; kept within 0–360). Other items are left unchanged.
FloorPlan rotateItem(FloorPlan plan, FloorItemRef ref, double degrees) {
  final angle = degrees % 360;
  switch (ref) {
    case TableRef(:final id):
      return plan.copyWith(
        tables: [
          for (final t in plan.tables)
            t.id == id ? t.copyWith(rotation: angle) : t,
        ],
      );
    case ElementRef(:final index):
      if (plan.elements[index] case final FixtureElement f) {
        return plan.copyWith(
          elements: [...plan.elements]..[index] = f.copyWith(rotation: angle),
        );
      }
      return plan;
    case OutlineEdgeRef():
      return plan;
  }
}

/// The rotation of a turnable item, in degrees: rounded rectangle, square,
/// circle and quarter circle tables, bars and fixtures. Null for anything
/// else.
double? itemRotation(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef() =>
    (sidedTable(plan, ref) ??
            barTable(plan, ref) ??
            circleTable(plan, ref) ??
            quarterCircleTable(plan, ref))
        ?.rotation,
  ElementRef(:final index) => switch (plan.elements[index]) {
    FixtureElement(:final rotation) => rotation,
    _ => null,
  },
  OutlineEdgeRef() => null,
};

/// The circle table [ref] points at, or null.
FloorTable? circleTable(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => switch (plan.tableById(id)) {
    final table? when table.shape.shape == TableShape.circle => table,
    _ => null,
  },
  _ => null,
};

/// The seat counts a circle table can have: the ones the Table
/// configuration has a diameter for.
final circleSeatCounts = FloorPlan.defaultCircleRadii.keys.toList();

/// [plan] with the circle table's seats set to [seats] (one of
/// [circleSeatCounts]; anything else changes nothing), spread around it.
/// The table takes that count's diameter around its center, and is nudged
/// back inside the room if it was inside.
FloorPlan setCircleSeats(FloorPlan plan, FloorItemRef ref, int seats) {
  final table = circleTable(plan, ref);
  if (table == null || !circleSeatCounts.contains(seats)) return plan;
  final next = plan.copyWith(
    tables: [
      for (final t in plan.tables)
        t.id == table.id
            ? t.copyWith(seatLayout: SeatLayout(around: seats))
            : t,
    ],
  );
  return _resizeTable(plan, next, table.id);
}

/// The most seats a bar can have.
const maxBarSeats = 10;

/// The bar [ref] points at, or null.
FloorTable? barTable(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => switch (plan.tableById(id)) {
    final table? when table.bar => table,
    _ => null,
  },
  _ => null,
};

/// A bar with [seats] seats, sized by the plan's bar slot: one
/// [FloorPlan.barSlotWidth] of counter per seat, [FloorPlan.barSlotDepth]
/// deep.
FloorTable sizeBar(FloorPlan plan, FloorTable bar, int seats) => bar.copyWith(
  width: seats * plan.barSlotWidth / plan.metersPerUnit,
  height: plan.barSlotDepth / plan.metersPerUnit,
  seatLayout: SeatLayout(bottom: seats),
);

/// [plan] with the bar's seats set to [seats] (1 to [maxBarSeats]), all on
/// one side. The counter grows or shrinks with them, around its center.
FloorPlan setBarSeats(FloorPlan plan, FloorItemRef ref, int seats) {
  final bar = barTable(plan, ref);
  if (bar == null) return plan;
  final changed = sizeBar(plan, bar, seats.clamp(1, maxBarSeats));
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
  for (final p in plan.floorOutline) {
    bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
  }
  for (final element in plan.elements) {
    bounds = bounds.expandToInclude(_elementBounds(element));
  }
  for (final t in plan.tables) {
    bounds = bounds.expandToInclude(_tableBounds(t));
  }
  return bounds;
}

/// The box around the item [ref] points at, in floor units: a table with
/// its seats, a fixture, or a wall's, door's or window's ends.
Rect itemBounds(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => _tableBounds(plan.tableById(id)!),
  ElementRef(:final index) => _elementBounds(plan.elements[index]),
  OutlineEdgeRef(:final index) => _pointsBounds(
    _edge(plan.floorOutline, index),
  ),
};

Rect _pointsBounds(Iterable<Offset> points) => points
    .map((p) => Rect.fromPoints(p, p))
    .reduce((a, b) => a.expandToInclude(b));

Rect _elementBounds(FloorElement element) => switch (element) {
  WallElement(:final points) => _pointsBounds(points),
  OpeningElement(:final ends) => _pointsBounds([ends.$1, ends.$2]),
  FixtureElement(
    :final x,
    :final y,
    :final width,
    :final height,
    :final rotation,
  ) =>
    _box(Offset(x, y), width, height, rotation),
};

Rect _tableBounds(FloorTable t) {
  final center = Offset(t.x, t.y);
  var bounds = _box(center, t.width, t.height, t.rotation);
  for (final seat in t.seats) {
    final at = t.rotation == 0
        ? seat.offset
        : Offset.fromDirection(
            seat.offset.direction + t.rotation * math.pi / 180,
            seat.offset.distance,
          );
    bounds = bounds.expandToInclude(
      Rect.fromCircle(center: center + at, radius: SeatLayout.seatSize / 2),
    );
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

/// The smallest and largest bar slot width and depth, in meters.
/// [plan] with a new bar slot size, in meters (kept within
/// [FloorPlan.barSlotWidthRange] and [FloorPlan.barSlotDepthRange]), and
/// every bar resized to it
/// around its center. A bar that was inside the room is nudged back in if
/// it now pokes through a wall.
FloorPlan setBarSlot(
  FloorPlan plan, {
  required double widthMeters,
  required double depthMeters,
}) {
  var changed = plan.copyWith(
    barSlotWidth: _clamp(widthMeters, FloorPlan.barSlotWidthRange),
    barSlotDepth: _clamp(depthMeters, FloorPlan.barSlotDepthRange),
  );
  changed = changed.copyWith(
    tables: [
      for (final t in changed.tables)
        t.bar ? sizeBar(changed, t, t.seats.length) : t,
    ],
  );
  for (final t in plan.tables) {
    if (t.bar && tableInsideRoom(plan, t)) {
      changed = placeTableInsideRoom(changed, t.id);
    }
  }
  return changed;
}

double _clamp(double value, (double, double) range) =>
    value.clamp(range.$1, range.$2).toDouble();

/// [plan] with every table that [resized] picks out sized again by
/// [sizeTable] after a settings change; tables that were inside the room
/// are nudged back in.
FloorPlan _resizeAll(
  FloorPlan before,
  FloorPlan plan,
  bool Function(FloorTable) resized,
) {
  var changed = plan.copyWith(
    tables: [for (final t in plan.tables) resized(t) ? sizeTable(plan, t) : t],
  );
  for (final t in before.tables) {
    if (resized(t) && tableInsideRoom(before, t)) {
      changed = placeTableInsideRoom(changed, t.id);
    }
  }
  return changed;
}

bool _isSquare(FloorTable t) =>
    t.shape.shape == TableShape.roundedRect && !t.bar && t.square;

bool _isRectangle(FloorTable t) =>
    t.shape.shape == TableShape.roundedRect && !t.bar && !t.square;

/// [plan] with a new square table side, in meters (kept within
/// [FloorPlan.squareSeatWidthRange]), and every square table resized.
FloorPlan setSquareSettings(FloorPlan plan, {required double widthMeters}) =>
    _resizeAll(
      plan,
      plan.copyWith(
        squareSeatWidth: _clamp(widthMeters, FloorPlan.squareSeatWidthRange),
      ),
      _isSquare,
    );

/// [plan] with new rectangle table settings, in meters (each kept within
/// its range), and every rectangle table resized.
FloorPlan setRectangleSettings(
  FloorPlan plan, {
  required double widthMeters,
  required double depthMeters,
  required double bufferMeters,
}) => _resizeAll(
  plan,
  plan.copyWith(
    rectSeatWidth: _clamp(widthMeters, FloorPlan.rectSeatWidthRange),
    rectSeatDepth: _clamp(depthMeters, FloorPlan.rectSeatDepthRange),
    rectBuffer: _clamp(bufferMeters, FloorPlan.rectBufferRange),
  ),
  _isRectangle,
);

/// Whether [t] is sized by [FloorPlan.circleRadii]: a circle with only
/// 4, 6, 8 or 10 seats, all around it.
bool isSizedCircleTable(FloorTable t) =>
    t.shape.shape == TableShape.circle &&
    t.seatLayout.count == t.seatLayout.around &&
    FloorPlan.defaultCircleRadii.containsKey(t.seatLayout.around);

/// [plan] with new circle table radii, in meters by seat count (each kept
/// within [FloorPlan.circleRadiusRange]; counts left out keep their value),
/// and every circle table with 4, 6, 8 or 10 seats resized.
FloorPlan setCircleSettings(
  FloorPlan plan, {
  required Map<int, double> radiiMeters,
}) => _resizeAll(
  plan,
  plan.copyWith(
    circleRadii: {
      for (final seats in FloorPlan.defaultCircleRadii.keys)
        seats: _clamp(
          radiiMeters[seats] ?? plan.circleRadii[seats]!,
          FloorPlan.circleRadiusRange(seats),
        ),
    },
  ),
  isSizedCircleTable,
);

/// Whether [t] is sized by [FloorPlan.quarterCircleRadii]: a quarter circle
/// with only 1, 2 or 3 seats of its own.
bool isSizedQuarterCircleTable(FloorTable t) =>
    t.shape.shape == TableShape.quarterCircle &&
    t.seatLayout.count == t.seatLayout.custom.length &&
    FloorPlan.defaultQuarterCircleRadii.containsKey(t.seatLayout.custom.length);

/// Where a quarter circle table [radius] across with its curve at [corner]
/// has its circle's center (the corner opposite the curve, relative to the
/// table's center), and the angle the curve starts at; it runs 90° from
/// there.
({Offset center, double start}) quarterCircleArc(
  QuarterCircleCorner corner,
  double radius,
) {
  final half = radius / 2;
  return switch (corner) {
    QuarterCircleCorner.topLeft => (center: Offset(half, half), start: math.pi),
    QuarterCircleCorner.topRight => (
      center: Offset(-half, half),
      start: -math.pi / 2,
    ),
    QuarterCircleCorner.bottomRight => (
      center: Offset(-half, -half),
      start: 0.0,
    ),
    QuarterCircleCorner.bottomLeft => (
      center: Offset(half, -half),
      start: math.pi / 2,
    ),
  };
}

/// The direction of seat [index] of [seats] on a quarter circle's curve,
/// from [quarterCircleArc]'s start: spread evenly, e.g. 15°, 45° and 75°
/// in for 3 seats.
double quarterCircleSeatAngle(double start, int index, int seats) =>
    start + math.pi / 2 * (index + 0.5) / seats;

/// [seats] seat positions for a quarter circle table [radius] floor units
/// across whose curve is at [corner]: spread evenly just outside the curve
/// (see [quarterCircleSeatAngle]). Relative to the table's center, like
/// [SeatLayout.custom].
List<Offset> quarterCircleSeats(
  QuarterCircleCorner corner,
  double radius,
  int seats,
) {
  final (:center, :start) = quarterCircleArc(corner, radius);
  final distance = radius + SeatLayout.seatGap + SeatLayout.seatSize / 2;
  return [
    for (var i = 0; i < seats; i++)
      center +
          Offset.fromDirection(
            quarterCircleSeatAngle(start, i, seats),
            distance,
          ),
  ];
}

/// The quarter circle table [ref] points at, or null.
FloorTable? quarterCircleTable(FloorPlan plan, FloorItemRef ref) =>
    switch (ref) {
      TableRef(:final id) => switch (plan.tableById(id)) {
        final table? when table.shape.shape == TableShape.quarterCircle =>
          table,
        _ => null,
      },
      _ => null,
    };

/// The seat counts a quarter circle table can have: the ones the Table
/// configuration has a radius for.
final quarterCircleSeatCounts = FloorPlan.defaultQuarterCircleRadii.keys
    .toList();

/// [plan] with the quarter circle table's seats set to [seats] (one of
/// [quarterCircleSeatCounts]; anything else changes nothing). The table
/// takes that count's radius and its seats are spread along the curve; it
/// is nudged back inside the room if it was inside.
FloorPlan setQuarterCircleSeats(FloorPlan plan, FloorItemRef ref, int seats) {
  final table = quarterCircleTable(plan, ref);
  if (table == null || !quarterCircleSeatCounts.contains(seats)) return plan;
  final next = plan.copyWith(
    tables: [
      for (final t in plan.tables)
        t.id == table.id
            ? t.copyWith(
                seatLayout: SeatLayout(
                  custom: quarterCircleSeats(
                    table.shape.corner!,
                    table.width,
                    seats,
                  ),
                ),
              )
            : t,
    ],
  );
  return _resizeTable(plan, next, table.id);
}

/// [plan] with new quarter circle table radii, in meters by seat count
/// (each kept within [FloorPlan.quarterCircleRadiusRange]; counts left out
/// keep their value), and every quarter circle table with 1, 2 or 3 seats
/// resized.
FloorPlan setQuarterCircleSettings(
  FloorPlan plan, {
  required Map<int, double> radiiMeters,
}) => _resizeAll(
  plan,
  plan.copyWith(
    quarterCircleRadii: {
      for (final seats in FloorPlan.defaultQuarterCircleRadii.keys)
        seats: _clamp(
          radiiMeters[seats] ?? plan.quarterCircleRadii[seats]!,
          FloorPlan.quarterCircleRadiusRange(seats),
        ),
    },
  ),
  isSizedQuarterCircleTable,
);
