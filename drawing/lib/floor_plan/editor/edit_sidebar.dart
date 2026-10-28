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
  });

  /// What the item is, e.g. "Table · circle".
  final String kind;
  final String name;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onClose;

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
