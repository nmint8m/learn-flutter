import 'package:flutter/material.dart';

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
    required this.onRemove,
    this.lengthMeters,
    this.onLengthChanged,
    this.walls,
    this.wallId,
    this.onWallChanged,
    this.sizeMeters,
    this.maxSizeMeters = 10,
    this.onSizeChanged,
  });

  /// What the item is, e.g. "Table · circle".
  final String kind;
  final String name;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onClose;

  /// Removes the item from the floor.
  final VoidCallback onRemove;

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
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onChanged: widget.onNameChanged,
            onSubmitted: (_) => widget.onClose(),
          ),
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
          const Divider(height: 32),
          OutlinedButton.icon(
            key: const ValueKey('remove-item'),
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
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
