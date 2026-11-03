import 'package:flutter/material.dart';

/// Asks which tables to link [tableName] with: every table in [tables] (the
/// other tables, already sorted) with a checkbox, ticked if it's in [linked].
/// Returns the ticked ids on Confirm, or null on Cancel.
Future<Set<String>?> showLinkTablesDialog(
  BuildContext context, {
  required String tableName,
  required List<({String id, String name})> tables,
  required Set<String> linked,
}) => showDialog<Set<String>>(
  context: context,
  builder: (_) =>
      _LinkTablesDialog(tableName: tableName, tables: tables, linked: linked),
);

class _LinkTablesDialog extends StatefulWidget {
  const _LinkTablesDialog({
    required this.tableName,
    required this.tables,
    required this.linked,
  });

  final String tableName;
  final List<({String id, String name})> tables;
  final Set<String> linked;

  @override
  State<_LinkTablesDialog> createState() => _LinkTablesDialogState();
}

class _LinkTablesDialogState extends State<_LinkTablesDialog> {
  late final _ticked = {...widget.linked};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Link tables with ${widget.tableName}'),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      content: SizedBox(
        width: 360,
        child: widget.tables.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('There are no other tables.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final table in widget.tables)
                    CheckboxListTile(
                      key: ValueKey('link-table-${table.id}'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      value: _ticked.contains(table.id),
                      title: Text(table.name),
                      onChanged: (on) => setState(
                        () => on == true
                            ? _ticked.add(table.id)
                            : _ticked.remove(table.id),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancel-link-tables'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-link-tables'),
          onPressed: () => Navigator.pop(context, _ticked),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

/// Asks to confirm a change to a group of linked tables, e.g. "Link C4 to
/// GR-1 [C1, C2, C3]?". Returns true on [confirmLabel], false on Cancel or
/// a tap outside.
Future<bool> confirmGroupChange(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            key: const ValueKey('cancel-group-change'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-group-change'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;
