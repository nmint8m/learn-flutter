import 'package:flutter/material.dart';

import 'floor_edits.dart'
    show
        SeatSide,
        maxBarSeats,
        maxSeatsPerEnd,
        maxSeatsPerLongSide,
        minSeatsPerEnd,
        minSeatsPerLongSide;

/// The right side bar for editing the selected item's name.
///
/// Give it a key per item (e.g. `ValueKey(ref)`) so the text field starts
/// fresh when another item is selected.
class EditSidebar extends StatefulWidget {
  const EditSidebar({
    super.key,
    required this.kind,
    required this.name,
    required this.onNameChanged,
    required this.onClose,
    this.lengthMeters,
    this.onLengthChanged,
    this.walls,
    this.wallId,
    this.onWallChanged,
    this.sizeMeters,
    this.maxSizeMeters = 10,
    this.onSizeChanged,
    this.seatsPerSide,
    this.squareTable = false,
    this.onSeatSideChanged,
    this.rectangleSeats,
    this.onRectangleSeatsChanged,
    this.rotation,
    this.onRotationChanged,
    this.barSeats,
    this.onBarSeatsChanged,
  });

  /// What the item is, e.g. "Table · circle".
  final String kind;
  final String name;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onClose;

  /// The length of a door or window, in meters. Null hides the length field
  /// (other items).
  final double? lengthMeters;
  final ValueChanged<double>? onLengthChanged;

  /// The walls a door or window can sit on, and the one it's on now. Null
  /// hides the wall choice (other items).
  final List<({String id, String name})>? walls;
  final String? wallId;
  final ValueChanged<String>? onWallChanged;

  /// The size of a fixture, in meters. Null hides the size fields (other
  /// items). A round fixture shows one Diameter field.
  final ({double width, double height, bool round})? sizeMeters;
  final double maxSizeMeters;
  final void Function({double? width, double? height})? onSizeChanged;

  /// Rounded rectangle and square tables: how many seats each side has (0:
  /// none). Null hides the seat picture (other items).
  final Map<SeatSide, int>? seatsPerSide;

  /// Draws the seat picture as a square table with one seat per side.
  final bool squareTable;
  final void Function(SeatSide side, {required bool included})?
  onSeatSideChanged;

  /// A rectangle table's seats on each long side and at each end. Null hides
  /// the seat counts (squares and other items).
  final ({int long, int ends})? rectangleSeats;
  final void Function({int? long, int? ends})? onRectangleSeatsChanged;

  /// The table's rotation, in degrees. Null hides the rotation slider.
  final double? rotation;
  final ValueChanged<double>? onRotationChanged;

  /// A bar's number of seats. Null hides the bar picture and seat count.
  final int? barSeats;
  final ValueChanged<int>? onBarSeatsChanged;

  @override
  State<EditSidebar> createState() => _EditSidebarState();
}

class _EditSidebarState extends State<EditSidebar> {
  late final _controller = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Edit item', style: theme.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
          Text(widget.kind, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('item-name'),
            controller: _controller,
            // No autofocus: the keyboard only opens when the field is tapped.
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onChanged: widget.onNameChanged,
            onSubmitted: (_) => widget.onClose(),
          ),
          if (widget.seatsPerSide case final seats?) ...[
            const SizedBox(height: 24),
            Text('Seats', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Tap a side to add or remove its seats.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _SeatSidePicker(
              seatsPerSide: seats,
              square: widget.squareTable,
              rectangleSeats: widget.rectangleSeats,
              onChanged: (side, {required included}) =>
                  widget.onSeatSideChanged?.call(side, included: included),
            ),
            if (widget.rectangleSeats case final counts?) ...[
              const SizedBox(height: 16),
              _RectangleSeatFields(
                widthSide: counts.ends,
                lengthSide: counts.long,
                onChanged: (width, length) => widget.onRectangleSeatsChanged
                    ?.call(ends: width, long: length),
              ),
            ],
          ],
          if (widget.barSeats case final seats?) ...[
            const SizedBox(height: 24),
            Text('Seats', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _BarPreview(seats: seats),
            const SizedBox(height: 16),
            _SeatCountField(
              seats: seats,
              onChanged: (n) => widget.onBarSeatsChanged?.call(n),
            ),
          ],
          if (widget.rotation case final rotation?) ...[
            const SizedBox(height: 24),
            _RotationField(
              degrees: rotation,
              onChanged: (value) => widget.onRotationChanged?.call(value),
            ),
          ],
          if (widget.walls case final walls?) ...[
            const SizedBox(height: 16),
            // Rebuilt when the wall changes (e.g. after dragging the door
            // onto another wall), so the shown choice stays current.
            KeyedSubtree(
              key: ValueKey(widget.wallId),
              child: DropdownButtonFormField<String>(
                key: const ValueKey('item-wall'),
                initialValue: widget.wallId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Wall',
                  helperText: 'Doors and windows always sit on a wall.',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final wall in walls)
                    DropdownMenuItem(
                      value: wall.id,
                      child: Text(wall.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) widget.onWallChanged?.call(id);
                },
              ),
            ),
          ],
          if (widget.lengthMeters case final meters?) ...[
            const SizedBox(height: 16),
            _LengthField(
              name: 'length',
              meters: meters,
              onChanged: (value) => widget.onLengthChanged?.call(value),
            ),
          ],
          if (widget.sizeMeters case final size?) ...[
            if (size.round) ...[
              const SizedBox(height: 16),
              _LengthField(
                name: 'diameter',
                meters: size.width,
                max: widget.maxSizeMeters,
                onChanged: (value) =>
                    widget.onSizeChanged?.call(width: value, height: value),
              ),
            ] else ...[
              const SizedBox(height: 16),
              _LengthField(
                name: 'width',
                meters: size.width,
                max: widget.maxSizeMeters,
                onChanged: (value) => widget.onSizeChanged?.call(width: value),
              ),
              const SizedBox(height: 16),
              _LengthField(
                name: 'height',
                meters: size.height,
                max: widget.maxSizeMeters,
                onChanged: (value) => widget.onSizeChanged?.call(height: value),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            'Changes show on the floor right away. Tap Save to keep them.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A length in meters: type it, or use − and + to change it by 10 cm.
///
/// [name] ("length", "width", …) is the label and names the keys:
/// `item-<name>`, `<name>-minus` and `<name>-plus`.
class _LengthField extends StatefulWidget {
  const _LengthField({
    required this.name,
    required this.meters,
    required this.onChanged,
    this.max = 10,
  });

  final String name;
  final double meters;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  State<_LengthField> createState() => _LengthFieldState();
}

class _LengthFieldState extends State<_LengthField> {
  static const _min = 0.3;
  static const _step = 0.1;

  double get _max => widget.max;

  /// The last valid length, which − and + start from.
  late double _value = widget.meters;
  late final _controller = TextEditingController(text: _format(_value));
  String? _error;

  static String _format(double meters) {
    final rounded = (meters * 100).roundToDouble() / 100;
    return rounded == rounded.roundToDouble()
        ? '${rounded.toInt()}'
        : '$rounded';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _typed(String text) {
    // Accept "1,5" as well as "1.5".
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || value < _min || value > _max) {
      setState(
        () =>
            _error = 'Enter a ${widget.name} from $_min to ${_format(_max)} m',
      );
      return;
    }
    setState(() {
      _error = null;
      _value = value;
    });
    widget.onChanged(value);
  }

  void _stepBy(double delta) {
    final value = (((_value + delta) * 100).roundToDouble() / 100).clamp(
      _min,
      _max,
    );
    setState(() {
      _error = null;
      _value = value;
      _controller.text = _format(value);
    });
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final label = '${name[0].toUpperCase()}${name.substring(1)}';
    final (shorter, longer) = name == 'length'
        ? ('Shorter', 'Longer')
        : ('Smaller', 'Bigger');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.outlined(
            key: ValueKey('$name-minus'),
            tooltip: '$shorter by 10 cm',
            icon: const Icon(Icons.remove),
            onPressed: _value > _min ? () => _stepBy(-_step) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: ValueKey('item-$name'),
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              suffixText: 'm',
              errorText: _error,
              errorMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            onChanged: _typed,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.outlined(
            key: ValueKey('$name-plus'),
            tooltip: '$longer by 10 cm',
            icon: const Icon(Icons.add),
            onPressed: _value < _max ? () => _stepBy(_step) : null,
          ),
        ),
      ],
    );
  }
}

/// A picture of the table with its seats, one tap area per side. A side's
/// seats are green when included and grey when not; tapping the side
/// switches them.
class _SeatSidePicker extends StatelessWidget {
  const _SeatSidePicker({
    required this.seatsPerSide,
    required this.square,
    required this.onChanged,
    this.rectangleSeats,
  });

  final Map<SeatSide, int> seatsPerSide;
  final bool square;

  /// A rectangle's seats per long side and end, shown on excluded sides.
  final ({int long, int ends})? rectangleSeats;
  final void Function(SeatSide side, {required bool included}) onChanged;

  static const _seat = 24.0;
  static const _band = 40.0; // Depth of each side's tap area.

  /// Seats shown on a side that has none: what it would get if included.
  int _shownOn(SeatSide side) {
    final count = seatsPerSide[side] ?? 0;
    if (count > 0) return count;
    final long = side == SeatSide.top || side == SeatSide.bottom;
    if (square) return 1;
    if (rectangleSeats case final r?) {
      final n = long ? r.long : r.ends;
      if (n > 0) return n;
    }
    return long ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final table = square ? const Size(88, 88) : const Size(136, 64);
    final total = Size(table.width + 2 * _band, table.height + 2 * _band);

    Widget side(SeatSide side) {
      final included = (seatsPerSide[side] ?? 0) > 0;
      final horizontal = side == SeatSide.top || side == SeatSide.bottom;
      final seats = [
        for (var i = 0; i < _shownOn(side); i++)
          Container(
            width: _seat,
            height: _seat,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: included ? Colors.green : Colors.grey.shade400,
              border: Border.all(
                color: included ? Colors.green.shade800 : Colors.grey.shade600,
              ),
            ),
          ),
      ];
      return Semantics(
        button: true,
        toggled: included,
        label: '${side.name} seats',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('seat-side-${side.name}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(side, included: !included),
            child: horizontal
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: seats,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: seats,
                  ),
          ),
        ),
      );
    }

    return Center(
      child: SizedBox.fromSize(
        size: total,
        child: Stack(
          children: [
            Positioned(
              left: _band,
              top: _band,
              width: table.width,
              height: table.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  border: Border.all(color: colors.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              left: _band,
              top: 0,
              width: table.width,
              height: _band,
              child: side(SeatSide.top),
            ),
            Positioned(
              left: _band,
              bottom: 0,
              width: table.width,
              height: _band,
              child: side(SeatSide.bottom),
            ),
            Positioned(
              left: 0,
              top: _band,
              width: _band,
              height: table.height,
              child: side(SeatSide.left),
            ),
            Positioned(
              right: 0,
              top: _band,
              width: _band,
              height: table.height,
              child: side(SeatSide.right),
            ),
          ],
        ),
      ),
    );
  }
}

/// The table's rotation: a slider in 15° steps, from 0° to 345°.
class _RotationField extends StatelessWidget {
  const _RotationField({required this.degrees, required this.onChanged});

  final double degrees;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = degrees.round() % 360;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Rotation', style: theme.textTheme.titleSmall),
            ),
            Text(
              '$shown°',
              key: const ValueKey('item-rotation-value'),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        Slider(
          key: const ValueKey('item-rotation'),
          value: (degrees % 360).clamp(0, 345),
          max: 345,
          divisions: 23,
          label: '$shown°',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// A picture of a bar counter with [seats] seats in a row below it, the
/// counter split into one stretch per seat.
class _BarPreview extends StatelessWidget {
  const _BarPreview({required this.seats});

  final int seats;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Up to 36 px per seat, narrower if the panel is.
        final perSeat = (constraints.maxWidth / seats).clamp(18.0, 36.0);
        final width = perSeat * seats;
        final seat = perSeat * 0.62;
        return Center(
          key: const ValueKey('bar-preview'),
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    border: Border.all(color: colors.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < seats; i++) ...[
                        if (i > 0)
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            indent: 6,
                            endIndent: 6,
                            color: colors.primary,
                          ),
                        const Expanded(child: SizedBox()),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < seats; i++)
                      Expanded(
                        child: Center(
                          child: Container(
                            key: ValueKey('bar-preview-seat-$i'),
                            width: seat,
                            height: seat,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surfaceContainerHighest,
                              border: Border.all(color: colors.outline),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A whole number of seats, 1 to [maxBarSeats]: type it, or use − and +.
class _SeatCountField extends StatefulWidget {
  const _SeatCountField({required this.seats, required this.onChanged});

  final int seats;
  final ValueChanged<int> onChanged;

  @override
  State<_SeatCountField> createState() => _SeatCountFieldState();
}

class _SeatCountFieldState extends State<_SeatCountField> {
  late final _controller = TextEditingController(text: '${widget.seats}');
  String? _error;

  @override
  void didUpdateWidget(_SeatCountField old) {
    super.didUpdateWidget(old);
    // Keep the text in step when the count changes from − or +.
    if (widget.seats != old.seats &&
        int.tryParse(_controller.text) != widget.seats) {
      _controller.text = '${widget.seats}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _typed(String text) {
    final n = int.tryParse(text.trim());
    if (n == null || n < 1 || n > maxBarSeats) {
      setState(() => _error = 'Enter 1 to $maxBarSeats seats');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(n);
  }

  void _step(int by) {
    final n = (widget.seats + by).clamp(1, maxBarSeats);
    setState(() {
      _error = null;
      _controller.text = '$n';
    });
    widget.onChanged(n);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.outlined(
            key: const ValueKey('bar-seats-minus'),
            tooltip: 'One seat fewer',
            icon: const Icon(Icons.remove),
            onPressed: widget.seats > 1 ? () => _step(-1) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const ValueKey('bar-seats'),
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Number of seats',
              helperText: 'Up to $maxBarSeats',
              errorText: _error,
              errorMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            onChanged: _typed,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.outlined(
            key: const ValueKey('bar-seats-plus'),
            tooltip: 'One more seat',
            icon: const Icon(Icons.add),
            onPressed: widget.seats < maxBarSeats ? () => _step(1) : null,
          ),
        ),
      ],
    );
  }
}

/// A rectangle table's seats on its width side (each end) and its length
/// side (each long side), as two number fields. Each has its range, and the
/// length side must have more seats than the width side; [onChanged] is only
/// called with a valid pair.
class _RectangleSeatFields extends StatefulWidget {
  const _RectangleSeatFields({
    required this.widthSide,
    required this.lengthSide,
    required this.onChanged,
  });

  final int widthSide;
  final int lengthSide;
  final void Function(int widthSide, int lengthSide) onChanged;

  @override
  State<_RectangleSeatFields> createState() => _RectangleSeatFieldsState();
}

class _RectangleSeatFieldsState extends State<_RectangleSeatFields> {
  late final _width = TextEditingController(text: '${widget.widthSide}');
  late final _length = TextEditingController(text: '${widget.lengthSide}');
  String? _widthError;
  String? _lengthError;

  @override
  void didUpdateWidget(_RectangleSeatFields old) {
    super.didUpdateWidget(old);
    // Follow changes from elsewhere (e.g. switching a side on), unless the
    // field already shows that number.
    if (int.tryParse(_width.text) != widget.widthSide &&
        widget.widthSide != old.widthSide) {
      _width.text = '${widget.widthSide}';
    }
    if (int.tryParse(_length.text) != widget.lengthSide &&
        widget.lengthSide != old.lengthSide) {
      _length.text = '${widget.lengthSide}';
    }
  }

  @override
  void dispose() {
    _width.dispose();
    _length.dispose();
    super.dispose();
  }

  void _typed(String _) {
    final width = int.tryParse(_width.text.trim());
    final length = int.tryParse(_length.text.trim());
    final widthOk =
        width != null && width >= minSeatsPerEnd && width <= maxSeatsPerEnd;
    final lengthOk =
        length != null &&
        length >= minSeatsPerLongSide &&
        length <= maxSeatsPerLongSide;
    setState(() {
      _widthError = widthOk
          ? null
          : 'Enter $minSeatsPerEnd to $maxSeatsPerEnd seats';
      _lengthError = !lengthOk
          ? 'Enter $minSeatsPerLongSide to $maxSeatsPerLongSide seats'
          : widthOk && length <= width
          ? 'Must be more than the width side ($width)'
          : null;
    });
    if (widthOk && lengthOk && length > width) {
      widget.onChanged(width, length);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label, String helper, String? error) =>
        InputDecoration(
          labelText: label,
          helperText: helper,
          errorText: error,
          errorMaxLines: 2,
          border: const OutlineInputBorder(),
        );
    return Column(
      children: [
        TextField(
          key: const ValueKey('rect-width-seats'),
          controller: _width,
          keyboardType: TextInputType.number,
          decoration: decoration(
            'Seats on width side',
            '$minSeatsPerEnd to $maxSeatsPerEnd, at each end',
            _widthError,
          ),
          onChanged: _typed,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('rect-length-seats'),
          controller: _length,
          keyboardType: TextInputType.number,
          decoration: decoration(
            'Seats on length side',
            '$minSeatsPerLongSide to $maxSeatsPerLongSide, along each long '
                'side; more than the width side',
            _lengthError,
          ),
          onChanged: _typed,
        ),
      ],
    );
  }
}
