import 'package:flutter/material.dart';

/// One value in a [showTableSettingsDialog], in the dialog's unit.
typedef TableSetting = ({
  String key,
  String label,
  double value,
  (double, double) range,
});

/// Asks for a table type's settings (e.g. a bar seat's width and depth), in
/// [unit] (meters by default), each within its range. Returns the new values
/// by [TableSetting.key], in that unit, or null if cancelled.
///
/// The fields are keyed `<keyPrefix>-<key>` and the Apply button
/// `<keyPrefix>-save`.
Future<Map<String, double>?> showTableSettingsDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String keyPrefix,
  required List<TableSetting> settings,
  String unit = 'm',
}) => showDialog(
  context: context,
  builder: (context) => _TableSettingsDialog(
    title: title,
    description: description,
    keyPrefix: keyPrefix,
    settings: settings,
    unit: unit,
  ),
);

class _TableSettingsDialog extends StatefulWidget {
  const _TableSettingsDialog({
    required this.title,
    required this.description,
    required this.keyPrefix,
    required this.settings,
    required this.unit,
  });

  final String title;
  final String description;
  final String keyPrefix;
  final List<TableSetting> settings;
  final String unit;

  @override
  State<_TableSettingsDialog> createState() => _TableSettingsDialogState();
}

class _TableSettingsDialogState extends State<_TableSettingsDialog> {
  late final _controllers = {
    for (final s in widget.settings)
      s.key: TextEditingController(text: _format(s.value)),
  };
  final _errors = <String, String?>{};

  static String _format(double value) {
    final rounded = (value * 100).roundToDouble() / 100;
    return rounded == rounded.roundToDouble()
        ? '${rounded.toInt()}'
        : '$rounded';
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final values = <String, double>{};
    setState(() {
      for (final s in widget.settings) {
        // "0,6" works as well as "0.6".
        final value = double.tryParse(
          _controllers[s.key]!.text.trim().replaceAll(',', '.'),
        );
        final (min, max) = s.range;
        if (value == null || value < min - 1e-9 || value > max + 1e-9) {
          _errors[s.key] =
              'Enter ${_format(min)} to ${_format(max)} ${widget.unit}';
        } else {
          _errors[s.key] = null;
          values[s.key] = value;
        }
      }
    });
    if (values.length == widget.settings.length) {
      Navigator.pop(context, values);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.description, style: theme.textTheme.bodySmall),
              for (final (i, s) in widget.settings.indexed) ...[
                const SizedBox(height: 16),
                TextField(
                  key: ValueKey('${widget.keyPrefix}-${s.key}'),
                  controller: _controllers[s.key],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: s.label,
                    suffixText: widget.unit,
                    helperText:
                        '${_format(s.range.$1)} to ${_format(s.range.$2)} '
                        '${widget.unit}',
                    errorText: _errors[s.key],
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: i == widget.settings.length - 1
                      ? (_) => _save()
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: ValueKey('${widget.keyPrefix}-save'),
          onPressed: _save,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
