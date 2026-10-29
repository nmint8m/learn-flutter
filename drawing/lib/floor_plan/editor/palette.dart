import 'dart:math' as math;
import 'dart:ui';

import '../../geometry/geometry_paths.dart';
import '../floor_plan.dart';
import 'floor_edits.dart' show quarterCircleSeats, sizeTable;

/// The groups shown in the design panel.
enum PaletteSection {
  roomAndDecor('Room & Decor'),
  tableAndSeat('Table & Seat');

  const PaletteSection(this.title);

  final String title;
}

/// Everything you can add from the design panel.
enum PaletteItem {
  wall('Wall', PaletteSection.roomAndDecor),
  entranceDoor('Entrance door', PaletteSection.roomAndDecor),
  window('Window', PaletteSection.roomAndDecor),
  plant('Plant', PaletteSection.roomAndDecor),
  fixture('Fixture', PaletteSection.roomAndDecor),
  roundedRectTable('Rectangle', PaletteSection.tableAndSeat),
  roundedSquareTable('Square', PaletteSection.tableAndSeat),
  barTable('Bar', PaletteSection.tableAndSeat),
  circleTable('Circle', PaletteSection.tableAndSeat),
  quarterCircleTable('Quarter circle', PaletteSection.tableAndSeat);

  const PaletteItem(this.label, this.section);

  final String label;
  final PaletteSection section;

  /// The table shape this item adds, or null for room & decor items.
  ShapeSpec? get tableShape => switch (this) {
    roundedRectTable ||
    roundedSquareTable ||
    barTable => const ShapeSpec.roundedRect(),
    circleTable => const ShapeSpec.circle(),
    quarterCircleTable => const ShapeSpec.quarterCircle(
      QuarterCircleCorner.bottomRight,
    ),
    _ => null,
  };
}

/// What [addPaletteItem] did: the new plan, plus a short description for a
/// confirmation message.
typedef PaletteResult = ({FloorPlan plan, String description});

/// Adds [item] to [plan], centered at [at] (in floor units).
///
/// The position is rounded to one decimal ([roundPosition]) and kept inside
/// the floor. New
/// tables get the next free id (`T8`, `T9`...) and a sensible default seat
/// layout for their shape.
PaletteResult addPaletteItem(FloorPlan plan, PaletteItem item, Offset at) {
  double snap(double v, double max) =>
      roundPosition(v).clamp(0, max).toDouble();
  final x = snap(at.dx, plan.width);
  final y = snap(at.dy, plan.height);

  FloorPlan withElement(FloorElement element) =>
      plan.copyWith(elements: [...plan.elements, element]);

  switch (item) {
    case PaletteItem.wall:
      return (
        plan: withElement(WallElement([Offset(x - 2, y), Offset(x + 2, y)])),
        description: 'Wall',
      );
    case PaletteItem.entranceDoor:
      return (
        plan: withElement(
          DoorElement(x: x, y: y, width: 2.5, label: 'Entrance'),
        ),
        description: 'Entrance door',
      );
    case PaletteItem.window:
      return (
        plan: withElement(WindowElement(x: x, y: y, width: 3)),
        description: 'Window',
      );
    case PaletteItem.plant:
      return (
        plan: withElement(
          FixtureElement(
            shape: const ShapeSpec.circle(),
            x: x,
            y: y,
            width: 1.6,
            height: 1.6,
            color: const Color(0xFFA5D6A7),
          ),
        ),
        description: 'Plant',
      );
    case PaletteItem.fixture:
      return (
        plan: withElement(
          FixtureElement(
            shape: const ShapeSpec.rect(),
            x: x,
            y: y,
            width: 4,
            height: 3,
            label: 'Fixture',
            color: const Color(0xFFECEFF1),
          ),
        ),
        description: 'Fixture',
      );
    case PaletteItem.barTable:
      // A bar: one row of seats along the counter, each with its own
      // status. Named "Bar", or "Bar 2", "Bar 3"... if that's taken.
      final number = nextTableNumber(plan);
      final labels = {for (final t in plan.tables) t.label};
      var name = 'Bar';
      for (var n = 2; labels.contains(name); n++) {
        name = 'Bar $n';
      }
      const seats = 4;
      final bar = FloorTable(
        id: 'T$number',
        label: name,
        shape: const ShapeSpec.roundedRect(),
        x: x,
        y: y,
        // Sized by the plan's bar slot: so much counter per seat.
        width: seats * plan.barSlotWidth / plan.metersPerUnit,
        height: plan.barSlotDepth / plan.metersPerUnit,
        seatLayout: const SeatLayout(bottom: seats),
        statusPerSeat: true,
        bar: true,
      );
      return (
        plan: plan.copyWith(tables: [...plan.tables, bar]),
        description: name,
      );
    case PaletteItem.roundedRectTable ||
        PaletteItem.roundedSquareTable ||
        PaletteItem.circleTable ||
        PaletteItem.quarterCircleTable:
      final number = nextTableNumber(plan);
      final table = FloorTable(
        id: 'T$number',
        label: '$number',
        shape: item.tableShape!,
        x: x,
        y: y,
        width: switch (item) {
          PaletteItem.circleTable || PaletteItem.roundedSquareTable => 3,
          _ => 4,
        },
        height: switch (item) {
          PaletteItem.circleTable || PaletteItem.roundedSquareTable => 3,
          PaletteItem.quarterCircleTable => 4,
          _ => 2,
        },
        seatLayout: _defaultSeats(item),
        square: item == PaletteItem.roundedSquareTable,
      );
      // Rectangles and squares are sized by the plan's table settings.
      final sized = sizeTable(plan, table);
      return (
        plan: plan.copyWith(tables: [...plan.tables, sized]),
        description: 'Table ${table.label}',
      );
  }
}

SeatLayout _defaultSeats(PaletteItem item) => switch (item) {
  // Six seats: two along each long side, one at each end.
  PaletteItem.roundedRectTable => const SeatLayout(
    top: 2,
    bottom: 2,
    left: 1,
    right: 1,
  ),
  PaletteItem.roundedSquareTable => const SeatLayout(
    top: 1,
    bottom: 1,
    left: 1,
    right: 1,
  ),
  PaletteItem.circleTable => const SeatLayout(around: 4),
  // Two seats just outside the curve. Sized by the plan's settings, which
  // also spread the seats along the curve.
  PaletteItem.quarterCircleTable => SeatLayout(
    custom: quarterCircleSeats(QuarterCircleCorner.bottomRight, 4, 2),
  ),
  _ => const SeatLayout(),
};

/// One more than the highest `T<number>` id, so new tables never clash.
int nextTableNumber(FloorPlan plan) {
  var highest = 0;
  for (final table in plan.tables) {
    final match = RegExp(r'^T(\d+)$').firstMatch(table.id);
    if (match != null) {
      highest = math.max(highest, int.parse(match.group(1)!));
    }
  }
  return highest + 1;
}
