import 'dart:math' as math;
import 'dart:ui';

import '../floor_plan.dart';

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
      DoorElement(:final x, :final y, :final width, :final vertical) ||
      WindowElement(
        :final x,
        :final y,
        :final width,
        :final vertical,
      ) => _nearSegment(point, _opening(x, y, width, vertical), 0.6),
      WallElement(:final points) => [
        for (var j = 1; j < points.length; j++) (points[j - 1], points[j]),
      ].any((segment) => _nearSegment(point, segment, 0.4)),
      FixtureElement() => false,
    };
    if (hit) return ElementRef(i);
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
        final DoorElement d => d.copyWith(x: d.x + delta.dx, y: d.y + delta.dy),
        final WindowElement w => w.copyWith(
          x: w.x + delta.dx,
          y: w.y + delta.dy,
        ),
        final FixtureElement f => f.copyWith(
          x: f.x + delta.dx,
          y: f.y + delta.dy,
        ),
      };
      return plan.copyWith(elements: [...plan.elements]..[index] = moved);
  }
}

/// [plan] with the item nudged so its position lands on half a floor unit,
/// e.g. after a drag.
FloorPlan snapItem(FloorPlan plan, FloorItemRef ref) {
  final anchor = _anchor(plan, ref);
  double snap(double v) => (v * 2).roundToDouble() / 2;
  return moveItem(plan, ref, Offset(snap(anchor.dx), snap(anchor.dy)) - anchor);
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
  }
}

/// The item's current name, or '' if it has none.
String itemName(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => plan.tableById(id)?.label ?? '',
  ElementRef(:final index) => plan.elements[index].label ?? '',
};

/// What kind of item it is, e.g. "Table · circle" or "Window".
String itemKind(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => 'Table · ${plan.tableById(id)?.shape.shape.name}',
  ElementRef(:final index) => switch (plan.elements[index]) {
    WallElement() => 'Wall',
    DoorElement() => 'Door',
    WindowElement() => 'Window',
    FixtureElement(:final shape) =>
      shape.shape == TableShape.circle ? 'Plant / round fixture' : 'Fixture',
  },
};

/// Whether [ref] still points at something in [plan].
bool itemExists(FloorPlan plan, FloorItemRef ref) => switch (ref) {
  TableRef(:final id) => plan.tableById(id) != null,
  ElementRef(:final index) => index < plan.elements.length,
};

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

(Offset, Offset) _opening(double x, double y, double width, bool vertical) {
  final half = width / 2;
  return vertical
      ? (Offset(x, y - half), Offset(x, y + half))
      : (Offset(x - half, y), Offset(x + half, y));
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
