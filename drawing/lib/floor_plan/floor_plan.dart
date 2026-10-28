import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../geometry/geometry_paths.dart';

/// Rounds a position (x, y, or a wall point, in floor units) to one
/// decimal, e.g. 12.34 → 12.3 and 12.35 → 12.4. Items are kept on these
/// positions when they are added, moved and saved.
double roundPosition(double value) => (value * 10).roundToDouble() / 10;

/// A restaurant floor plan: the room, its fixed elements, and its tables.
///
/// Every position and size is in *floor units*, not pixels. You choose what a
/// unit means (e.g. 50 cm); the view converts units to pixels when it draws,
/// so the same plan fits any screen.
///
/// This is only the layout. Whether a table is free or occupied is kept
/// separately (see `TableStatus`), linked by the table's [FloorTable.id].
class FloorPlan {
  const FloorPlan({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    this.gridSize = 1,
    this.metersPerUnit = 0.5,
    this.outline,
    this.elements = const [],
    this.tables = const [],
  });

  final String id;
  final String name;
  final double width;
  final double height;

  /// Spacing of the background grid lines, in floor units. 0 hides the grid.
  final double gridSize;

  /// How long one floor unit is in real life, in meters. Used to show and
  /// edit sizes in meters (e.g. a door's length). The default, 0.5, makes a
  /// 4 × 2 table 2 m × 1 m.
  final double metersPerUnit;

  /// The room's shape, as the corners of a polygon in order. Only the area
  /// inside is floor, and its edge is drawn as the outer wall. Leave it out
  /// for a plain [width] × [height] rectangle.
  final List<Offset>? outline;

  /// [outline], or the full rectangle if there is none.
  List<Offset> get floorOutline =>
      outline ??
      [Offset.zero, Offset(width, 0), Offset(width, height), Offset(0, height)];

  final List<FloorElement> elements;
  final List<FloorTable> tables;

  /// Reads a plan from a JSON string. Throws a [FormatException] that names
  /// the bad field if the JSON doesn't match the expected format.
  static FloorPlan parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Floor plan is not valid JSON: ${e.message}');
    }
    return FloorPlan.fromJson(json);
  }

  /// Reads a plan from already-decoded JSON (e.g. from an API response).
  factory FloorPlan.fromJson(Object? decoded) {
    final json = _Json.root(decoded);
    final plan = FloorPlan(
      id: json.string('id'),
      name: json.string('name', fallback: ''),
      width: json.positiveNumber('width'),
      height: json.positiveNumber('height'),
      gridSize: json.number('gridSize', fallback: 1),
      metersPerUnit: json.positiveNumber('metersPerUnit', fallback: 0.5),
      outline: json.optionalPointList('outline', minLength: 3),
      elements: [
        for (final e in json.objectList('elements')) FloorElement._fromJson(e),
      ],
      tables: [
        for (final t in json.objectList('tables')) FloorTable._fromJson(t),
      ],
    );

    final ids = <String>{};
    for (final table in plan.tables) {
      if (!ids.add(table.id)) {
        throw FormatException('Two tables have the id "${table.id}"');
      }
    }
    return plan;
  }

  /// A copy with some parts replaced, e.g. after adding a table.
  FloorPlan copyWith({
    List<Offset>? outline,
    List<FloorElement>? elements,
    List<FloorTable>? tables,
  }) => FloorPlan(
    id: id,
    name: name,
    width: width,
    height: height,
    gridSize: gridSize,
    metersPerUnit: metersPerUnit,
    outline: outline ?? this.outline,
    elements: elements ?? this.elements,
    tables: tables ?? this.tables,
  );

  /// The plan as JSON, in the same format [parse] reads.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'width': _num(width),
    'height': _num(height),
    'gridSize': _num(gridSize),
    'metersPerUnit': _num(metersPerUnit),
    if (outline case final points?) 'outline': _points(points),
    'elements': [for (final e in elements) e.toJson()],
    'tables': [for (final t in tables) t.toJson()],
  };

  /// [toJson] as text, indented for people to read. Lists of numbers (points)
  /// stay on one line.
  String encode() => '${_prettyJson(toJson(), '')}\n';

  FloorTable? tableById(String id) {
    for (final table in tables) {
      if (table.id == id) return table;
    }
    return null;
  }
}

/// Which shape to draw, plus the options some shapes need. Shared by tables
/// and fixtures, and mapped straight onto the functions in
/// `geometry_paths.dart`.
class ShapeSpec {
  const ShapeSpec.rect() : this._(TableShape.rect);
  const ShapeSpec.roundedRect({double cornerRadius = 0.4})
    : this._(TableShape.roundedRect, cornerRadius: cornerRadius);
  const ShapeSpec.circle() : this._(TableShape.circle);
  const ShapeSpec.semicircle(SemicircleSide side)
    : this._(TableShape.semicircle, side: side);
  const ShapeSpec.quarterCircle(QuarterCircleCorner corner)
    : this._(TableShape.quarterCircle, corner: corner);

  const ShapeSpec._(
    this.shape, {
    this.cornerRadius = 0,
    this.side,
    this.corner,
  });

  factory ShapeSpec._fromJson(_Json json) {
    return switch (json.enumValue('shape', TableShape.values)) {
      TableShape.rect => const ShapeSpec.rect(),
      TableShape.roundedRect => ShapeSpec.roundedRect(
        cornerRadius: json.number('cornerRadius', fallback: 0.4),
      ),
      TableShape.circle => const ShapeSpec.circle(),
      TableShape.semicircle => ShapeSpec.semicircle(
        json.enumValue('side', SemicircleSide.values),
      ),
      TableShape.quarterCircle => ShapeSpec.quarterCircle(
        json.enumValue('corner', QuarterCircleCorner.values),
      ),
    };
  }

  final TableShape shape;

  /// In floor units. Only used by [TableShape.roundedRect].
  final double cornerRadius;
  final SemicircleSide? side;
  final QuarterCircleCorner? corner;

  Map<String, Object?> toJson() => {
    'shape': shape.name,
    if (shape == TableShape.roundedRect) 'cornerRadius': _num(cornerRadius),
    if (side case final side?) 'side': side.name,
    if (corner case final corner?) 'corner': corner.name,
  };

  /// The outline inside [rect] (in pixels). [pixelsPerUnit] converts
  /// [cornerRadius] from floor units to pixels.
  Path path(Rect rect, double pixelsPerUnit) => switch (shape) {
    TableShape.rect => Path()..addRect(rect),
    TableShape.roundedRect => roundedRectPath(
      rect,
      radius: cornerRadius * pixelsPerUnit,
    ),
    TableShape.circle => circlePath(rect),
    TableShape.semicircle => semicirclePath(rect, side!),
    TableShape.quarterCircle => quarterCirclePath(rect, corner!),
  };
}

enum TableShape { rect, roundedRect, circle, semicircle, quarterCircle }

// ---------------------------------------------------------------------------
// Fixed elements: walls, doors, windows, fixtures
// ---------------------------------------------------------------------------

/// Something on the floor that isn't a table. `sealed`, so a `switch` over
/// the kinds must handle all of them.
sealed class FloorElement {
  const FloorElement();

  /// A name for people, e.g. "Kitchen" or "Entrance". Optional.
  String? get label;

  Map<String, Object?> toJson();

  factory FloorElement._fromJson(_Json json) {
    return switch (json.string('type')) {
      'wall' => WallElement._fromJson(json),
      'door' => DoorElement._fromJson(json),
      'window' => WindowElement._fromJson(json),
      'fixture' => FixtureElement._fromJson(json),
      final other => throw json.error(
        '"type" must be wall, door, window or fixture, not "$other"',
      ),
    };
  }
}

/// A wall drawn as a line through [points], in order. Repeat the first point
/// at the end to close a room.
class WallElement extends FloorElement {
  const WallElement(this.points, {this.label});

  factory WallElement._fromJson(_Json json) {
    final points = json.pointList('points');
    if (points.length < 2) throw json.error('a wall needs at least 2 points');
    return WallElement(points, label: json.optionalString('label'));
  }

  final List<Offset> points;

  @override
  final String? label;

  WallElement copyWith({List<Offset>? points, String? label}) =>
      WallElement(points ?? this.points, label: label ?? this.label);

  @override
  Map<String, Object?> toJson() => {
    'type': 'wall',
    if (label != null) 'label': label,
    'points': _points(points),
  };
}

/// A door or window: an opening that always sits on a wall.
///
/// ([x], [y]) is its middle, and it runs along the wall at [angle] degrees
/// (0 = left to right, 90 = top to bottom). The editor keeps it on the
/// nearest wall: see `stickOpenings` in `floor_edits.dart`.
sealed class OpeningElement extends FloorElement {
  const OpeningElement({
    required this.x,
    required this.y,
    required this.width,
    this.angle = 0,
    this.label,
  });

  final double x;
  final double y;

  /// Length along the wall, in floor units.
  final double width;

  /// Direction of the wall it sits on, in degrees, from 0 up to (not
  /// including) 180.
  final double angle;

  @override
  final String? label;

  Offset get center => Offset(x, y);

  /// A unit-length step along the wall.
  Offset get along => Offset.fromDirection(angle * math.pi / 180);

  /// The opening's two ends.
  (Offset, Offset) get ends =>
      (center - along * (width / 2), center + along * (width / 2));

  OpeningElement copyWith({
    double? x,
    double? y,
    double? width,
    double? angle,
    String? label,
  });

  static double _angleFromJson(_Json json) {
    if (json.has('angle')) return normalizeAngle(json.number('angle'));
    final orientation = json.string('orientation', fallback: 'horizontal');
    if (orientation != 'horizontal' && orientation != 'vertical') {
      throw json.error('"orientation" must be horizontal or vertical');
    }
    return orientation == 'vertical' ? 90 : 0;
  }

  Map<String, Object?> _json(String type) => {
    'type': type,
    if (label != null) 'label': label,
    'x': _position(x),
    'y': _position(y),
    'width': _num(width),
    // Straight walls use the readable form; slanted ones store the angle.
    if (angle == 90)
      'orientation': 'vertical'
    else if (angle != 0)
      'angle': _num(angle),
  };
}

/// An angle in degrees, folded into 0 ≤ angle < 180 (a door at 190° lies
/// the same way as one at 10°). Values within a hair of 0 or 90 become
/// exactly 0 or 90.
double normalizeAngle(double degrees) {
  var a = degrees % 180;
  if (a < 0) a += 180;
  for (final exact in const [0.0, 90.0, 180.0]) {
    if ((a - exact).abs() < 1e-6) return exact % 180;
  }
  return a;
}

/// A door: a gap in the wall.
class DoorElement extends OpeningElement {
  const DoorElement({
    required super.x,
    required super.y,
    required super.width,
    super.angle,
    super.label,
  });

  factory DoorElement._fromJson(_Json json) => DoorElement(
    x: json.number('x'),
    y: json.number('y'),
    width: json.positiveNumber('width'),
    angle: OpeningElement._angleFromJson(json),
    label: json.optionalString('label'),
  );

  @override
  DoorElement copyWith({
    double? x,
    double? y,
    double? width,
    double? angle,
    String? label,
  }) => DoorElement(
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    angle: angle ?? this.angle,
    label: label ?? this.label,
  );

  @override
  Map<String, Object?> toJson() => _json('door');
}

/// A window set into a wall.
class WindowElement extends OpeningElement {
  const WindowElement({
    required super.x,
    required super.y,
    required super.width,
    super.angle,
    super.label,
  });

  factory WindowElement._fromJson(_Json json) => WindowElement(
    x: json.number('x'),
    y: json.number('y'),
    width: json.positiveNumber('width'),
    angle: OpeningElement._angleFromJson(json),
    label: json.optionalString('label'),
  );

  @override
  WindowElement copyWith({
    double? x,
    double? y,
    double? width,
    double? angle,
    String? label,
  }) => WindowElement(
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    angle: angle ?? this.angle,
    label: label ?? this.label,
  );

  @override
  Map<String, Object?> toJson() => _json('window');
}

/// A fixed, non-bookable object: kitchen, plant, pillar, stage...
class FixtureElement extends FloorElement {
  const FixtureElement({
    required this.shape,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.label,
    this.color,
  });

  factory FixtureElement._fromJson(_Json json) => FixtureElement(
    shape: ShapeSpec._fromJson(json),
    x: json.number('x'),
    y: json.number('y'),
    width: json.positiveNumber('width'),
    height: json.positiveNumber('height'),
    rotation: json.number('rotation', fallback: 0),
    label: json.optionalString('label'),
    color: json.optionalColor('color'),
  );

  final ShapeSpec shape;

  /// Center, in floor units.
  final double x;
  final double y;
  final double width;
  final double height;

  /// Degrees, clockwise, around the center.
  final double rotation;

  @override
  final String? label;
  final Color? color;

  FixtureElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? label,
  }) => FixtureElement(
    shape: shape,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation,
    label: label ?? this.label,
    color: color,
  );

  @override
  Map<String, Object?> toJson() => {
    'type': 'fixture',
    if (label != null) 'label': label,
    ...shape.toJson(),
    'x': _position(x),
    'y': _position(y),
    'width': _num(width),
    'height': _num(height),
    if (rotation != 0) 'rotation': _num(rotation),
    if (color case final color?) 'color': _hex(color),
  };
}

// ---------------------------------------------------------------------------
// Tables and seats
// ---------------------------------------------------------------------------

class FloorTable {
  const FloorTable({
    required this.id,
    required this.label,
    required this.shape,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.seatLayout = const SeatLayout(),
    this.statusPerSeat = false,
  });

  factory FloorTable._fromJson(_Json json) {
    final id = json.string('id');
    final inTable = json.withContext('table "$id"');
    return FloorTable(
      id: id,
      label: inTable.string('label', fallback: id),
      shape: ShapeSpec._fromJson(inTable),
      x: inTable.number('x'),
      y: inTable.number('y'),
      width: inTable.positiveNumber('width'),
      height: inTable.positiveNumber('height'),
      rotation: inTable.number('rotation', fallback: 0),
      seatLayout: SeatLayout._fromJson(inTable.optionalObject('seats')),
      statusPerSeat: inTable.boolean('statusPerSeat', fallback: false),
    );
  }

  /// Links this table to its live status and bookings.
  final String id;
  final String label;
  final ShapeSpec shape;

  /// Center, in floor units.
  final double x;
  final double y;
  final double width;
  final double height;

  /// Degrees, clockwise, around the center. Seats turn with the table.
  final double rotation;
  final SeatLayout seatLayout;

  /// When true, each seat has its own status (free, occupied...) instead of
  /// the whole table sharing one, e.g. a bar counter where strangers sit side
  /// by side. Statuses are then looked up by seat id ([Seat.id]) instead of
  /// table id.
  final bool statusPerSeat;

  /// Every seat, positioned relative to the table's center, before rotation.
  List<Seat> get seats => seatLayout.seatsFor(this);

  FloorTable copyWith({String? id, double? x, double? y, String? label}) =>
      FloorTable(
        id: id ?? this.id,
        label: label ?? this.label,
        shape: shape,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width,
        height: height,
        rotation: rotation,
        seatLayout: seatLayout,
        statusPerSeat: statusPerSeat,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    ...shape.toJson(),
    'x': _position(x),
    'y': _position(y),
    'width': _num(width),
    'height': _num(height),
    if (rotation != 0) 'rotation': _num(rotation),
    'seats': seatLayout.toJson(),
    if (statusPerSeat) 'statusPerSeat': true,
  };
}

/// One chair. [offset] is from the table's center, in floor units.
class Seat {
  const Seat({required this.id, required this.number, required this.offset});

  /// `<table id>-<number>`, e.g. `BAR-3`.
  final String id;

  /// 1, 2, 3... in the order the seats are listed: top, bottom, left, right,
  /// around, then custom. Within a side, left to right or top to bottom.
  final int number;
  final Offset offset;
}

/// How seats are arranged around a table.
///
/// Usually a rule ("2 on top, 2 on the bottom", "4 around"), so the seats
/// follow when the table is resized. [custom] positions are for odd shapes
/// like booths and corner tables. The kinds can be mixed.
class SeatLayout {
  const SeatLayout({
    this.top = 0,
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
    this.around = 0,
    this.custom = const [],
  });

  factory SeatLayout._fromJson(_Json? json) {
    if (json == null) return const SeatLayout();
    final seats = json.withContext('seats');
    return SeatLayout(
      top: seats.count('top'),
      bottom: seats.count('bottom'),
      left: seats.count('left'),
      right: seats.count('right'),
      around: seats.count('around'),
      custom: [
        for (final s in seats.objectList('custom'))
          Offset(s.number('x'), s.number('y')),
      ],
    );
  }

  final int top;
  final int bottom;
  final int left;
  final int right;

  /// Spread evenly around a round table, starting at the top.
  final int around;
  final List<Offset> custom;

  int get count => top + bottom + left + right + around + custom.length;

  Map<String, Object?> toJson() => {
    if (top > 0) 'top': top,
    if (bottom > 0) 'bottom': bottom,
    if (left > 0) 'left': left,
    if (right > 0) 'right': right,
    if (around > 0) 'around': around,
    if (custom.isNotEmpty)
      'custom': [
        for (final p in custom) {'x': _num(p.dx), 'y': _num(p.dy)},
      ],
  };

  /// Seat size and the gap between a seat and the table edge, in floor units.
  static const seatSize = 0.8;
  static const seatGap = 0.15;

  List<Seat> seatsFor(FloorTable table) {
    final halfW = table.width / 2;
    final halfH = table.height / 2;
    // Distance from the table edge to a seat's center.
    const out = seatGap + seatSize / 2;

    // `n` seats spread evenly along a side of the given length.
    Iterable<double> spread(int n, double length) sync* {
      for (var i = 0; i < n; i++) {
        yield -length / 2 + length * (i + 0.5) / n;
      }
    }

    final offsets = <Offset>[
      for (final x in spread(top, table.width)) Offset(x, -halfH - out),
      for (final x in spread(bottom, table.width)) Offset(x, halfH + out),
      for (final y in spread(left, table.height)) Offset(-halfW - out, y),
      for (final y in spread(right, table.height)) Offset(halfW + out, y),
      for (var i = 0; i < around; i++)
        Offset.fromDirection(
          -math.pi / 2 + 2 * math.pi * i / around,
          1,
        ).scale(halfW + out, halfH + out),
      ...custom,
    ];

    return [
      for (var i = 0; i < offsets.length; i++)
        Seat(id: '${table.id}-${i + 1}', number: i + 1, offset: offsets[i]),
    ];
  }
}

// ---------------------------------------------------------------------------
// JSON reading helpers
// ---------------------------------------------------------------------------

/// A JSON object plus where it came from, so errors can say exactly which
/// field is wrong, e.g. `table "T2" > seats: "around" must be a whole number`.
class _Json {
  _Json(this._map, this._context);

  factory _Json.root(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Floor plan must be a JSON object');
    }
    return _Json(json, 'floor plan');
  }

  final Map<String, dynamic> _map;
  final String _context;

  _Json withContext(String context) => _Json(_map, context);

  FormatException error(String message) =>
      FormatException('$_context: $message');

  Object? _required(String key) {
    if (!_map.containsKey(key)) throw error('missing "$key"');
    return _map[key];
  }

  String string(String key, {String? fallback}) {
    final value = fallback != null && !_map.containsKey(key)
        ? fallback
        : _required(key);
    if (value is! String) throw error('"$key" must be text');
    return value;
  }

  bool boolean(String key, {required bool fallback}) {
    final value = _map[key] ?? fallback;
    if (value is! bool) throw error('"$key" must be true or false');
    return value;
  }

  bool has(String key) => _map.containsKey(key);

  String? optionalString(String key) =>
      _map.containsKey(key) ? string(key) : null;

  double number(String key, {double? fallback}) {
    final value = fallback != null && !_map.containsKey(key)
        ? fallback
        : _required(key);
    if (value is! num) throw error('"$key" must be a number');
    return value.toDouble();
  }

  double positiveNumber(String key, {double? fallback}) {
    final value = number(key, fallback: fallback);
    if (value <= 0) throw error('"$key" must be greater than 0');
    return value;
  }

  int count(String key) {
    final value = _map[key] ?? 0;
    if (value is! int || value < 0) {
      throw error('"$key" must be a whole number, 0 or more');
    }
    return value;
  }

  T enumValue<T extends Enum>(String key, List<T> values) {
    final name = string(key);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw error(
      '"$key" must be one of ${values.map((v) => v.name).join(', ')}, '
      'not "$name"',
    );
  }

  _Json? optionalObject(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is! Map<String, dynamic>) throw error('"$key" must be an object');
    return _Json(value, _context);
  }

  List<_Json> objectList(String key) {
    final value = _map[key] ?? const [];
    if (value is! List) throw error('"$key" must be a list');
    return [
      for (var i = 0; i < value.length; i++)
        if (value[i] case final Map<String, dynamic> item)
          _Json(item, '$_context > $key[$i]')
        else
          throw error('"$key[$i]" must be an object'),
    ];
  }

  List<Offset>? optionalPointList(String key, {required int minLength}) {
    if (!_map.containsKey(key)) return null;
    final points = pointList(key);
    if (points.length < minLength) {
      throw error('"$key" needs at least $minLength points');
    }
    return points;
  }

  List<Offset> pointList(String key) {
    final value = _required(key);
    if (value is! List) throw error('"$key" must be a list of [x, y] pairs');
    return [
      for (final p in value)
        if (p case [final num x, final num y])
          Offset(x.toDouble(), y.toDouble())
        else
          throw error('every item in "$key" must be an [x, y] pair'),
    ];
  }

  /// A color written as "#RRGGBB" or "#AARRGGBB".
  Color? optionalColor(String key) {
    final text = optionalString(key);
    if (text == null) return null;
    final hex = text.startsWith('#') ? text.substring(1) : text;
    final value = int.tryParse(hex, radix: 16);
    if (value == null || (hex.length != 6 && hex.length != 8)) {
      throw error('"$key" must look like #RRGGBB, not "$text"');
    }
    return Color(hex.length == 6 ? 0xFF000000 | value : value);
  }
}

// ---------------------------------------------------------------------------
// JSON writing helpers
// ---------------------------------------------------------------------------

/// Whole numbers are written without ".0", and others rounded to 2 decimals,
/// so the file stays readable after moving things around.
/// Positions are written to one decimal, like [roundPosition].
num _position(double value) => _num(roundPosition(value));

num _num(double value) {
  final rounded = (value * 100).roundToDouble() / 100;
  return rounded == rounded.roundToDouble() ? rounded.toInt() : rounded;
}

List<List<num>> _points(List<Offset> points) => [
  for (final p in points) [_position(p.dx), _position(p.dy)],
];

String _hex(Color color) {
  final argb = color.toARGB32();
  final hex = argb.toRadixString(16).padLeft(8, '0').toUpperCase();
  // Opaque colors are written as #RRGGBB, like the hand-written file.
  return '#${argb >> 24 == 0xFF ? hex.substring(2) : hex}';
}

/// Like `JsonEncoder.withIndent`, but a list without objects inside (e.g. a
/// point `[3, 4]` or a list of points) stays on one line.
String _prettyJson(Object? value, String indent) {
  const step = '  ';
  final inner = '$indent$step';
  if (value is Map) {
    if (value.isEmpty) return '{}';
    final entries = [
      for (final MapEntry(:key, :value) in value.entries)
        '$inner${jsonEncode(key)}: ${_prettyJson(value, inner)}',
    ];
    return '{\n${entries.join(',\n')}\n$indent}';
  }
  if (value is List && value.any((v) => v is Map)) {
    final items = [for (final v in value) '$inner${_prettyJson(v, inner)}'];
    return '[\n${items.join(',\n')}\n$indent]';
  }
  return jsonEncode(value);
}
