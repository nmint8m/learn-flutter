import 'package:flutter/material.dart';

import 'floor_map_library.dart';
import 'floor_plan_page.dart';

/// The landing page, "All Floor plan": every floor map as a card with its
/// name, tables and seats.
///
/// Tapping a card floats its options next to the finger:
///   * Configure: rename it, and enable or disable it.
///   * Edit (enabled maps): open it with all 3 steps.
///   * View only (disabled maps): open it on step 3, Review, only.
///   * Duplicate: add "Copy of `name`" after it.
///   * Remove: asks first, with ✓ and ✕.
///
/// Double-tapping a card opens it straight away, like Edit (or View only).
class FloorMapsPage extends StatefulWidget {
  const FloorMapsPage({
    super.key,
    this.library = const JsonFileFloorMapLibrary(),
    this.actions = const [],
  });

  final FloorMapLibrary library;

  /// Extra app bar buttons.
  final List<Widget> actions;

  @override
  State<FloorMapsPage> createState() => _FloorMapsPageState();
}

enum _MapAction { configure, edit, viewOnly, duplicate, remove }

class _FloorMapsPageState extends State<FloorMapsPage> {
  late Future<List<FloorMap>> _loaded = widget.library.load();

  /// The maps after changes. Null until the first change.
  List<FloorMap>? _maps;

  void _reload() => setState(() {
    _maps = null;
    _loaded = widget.library.load();
  });

  Future<void> _change(List<FloorMap> maps) async {
    setState(() => _maps = maps);
    try {
      await widget.library.saveList(maps);
    } catch (e) {
      _showMessage('Could not save: $e');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onMapTapped(
    List<FloorMap> maps,
    FloorMap map,
    Offset at,
  ) async {
    final action = await _showFloatingAt<_MapAction>(
      context,
      at,
      (context) => _MapOptions(map: map),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _MapAction.configure:
        final result = await showDialog<({String name, bool enabled})>(
          context: context,
          builder: (_) => _ConfigureDialog(map: map),
        );
        if (result == null) return;
        await _change([
          for (final m in maps)
            m.id == map.id
                ? m.copyWith(name: result.name, enabled: result.enabled)
                : m,
        ]);
      case _MapAction.edit || _MapAction.viewOnly:
        await _open(map);
      case _MapAction.duplicate:
        await _duplicate(maps, map);
      case _MapAction.remove:
        final remove = await _showFloatingAt<bool>(
          context,
          at,
          (context) => _RemoveQuestion(name: map.name),
        );
        if (remove != true) return;
        await _change([
          for (final m in maps)
            if (m.id != map.id) m,
        ]);
        try {
          await widget.library.removePlan(map.id);
        } catch (e) {
          _showMessage('Could not remove: $e');
        }
    }
  }

  /// Opens [map] in the floor plan editor: all 3 steps when it's enabled,
  /// view only when it's disabled.
  Future<void> _open(FloorMap map) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorPlanPage(
          repository: FloorMapPlanRepository(widget.library, map),
          viewOnly: !map.enabled,
          mapName: map.name,
        ),
      ),
    );
    // Picks up anything saved while it was open.
    if (mounted) _reload();
  }

  Future<void> _duplicate(List<FloorMap> maps, FloorMap map) async {
    final ids = {for (final m in maps) m.id};
    var id = 'map-${DateTime.now().microsecondsSinceEpoch}';
    while (ids.contains(id)) {
      id = '$id-1';
    }
    final copy = FloorMap(
      id: id,
      name: 'Copy of ${map.name}',
      enabled: map.enabled,
      plan: map.plan,
    );
    try {
      await widget.library.savePlan(id, copy.plan);
    } catch (e) {
      _showMessage('Could not duplicate: $e');
      return;
    }
    // Right after the original.
    final at = maps.indexWhere((m) => m.id == map.id) + 1;
    await _change([...maps]..insert(at, copy));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Floor plan'),
        actions: widget.actions,
      ),
      body: FutureBuilder<List<FloorMap>>(
        future: _loaded,
        builder: (context, snapshot) {
          final maps = _maps ?? snapshot.data;
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load the floor maps.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }
          if (maps == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (maps.isEmpty) {
            return const Center(child: Text('No floor maps'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 168,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: maps.length,
            itemBuilder: (context, i) => _MapCard(
              map: maps[i],
              onTap: (at) => _onMapTapped(maps, maps[i], at),
              onDoubleTap: () => _open(maps[i]),
            ),
          );
        },
      ),
    );
  }
}

/// A floor map's card: its name, tables and seats, and "Disabled" when it
/// can only be viewed. Reports where it was tapped, to float the options
/// there.
class _MapCard extends StatefulWidget {
  const _MapCard({
    required this.map,
    required this.onTap,
    required this.onDoubleTap,
  });

  final FloorMap map;
  final ValueChanged<Offset> onTap;

  /// Opens the map straight away, without the options.
  final VoidCallback onDoubleTap;

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  Offset? _tapAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final map = widget.map;
    final muted = map.enabled ? colors.onSurface : colors.onSurfaceVariant;

    return Card(
      key: ValueKey('floor-map-${map.id}'),
      clipBehavior: Clip.antiAlias,
      color: map.enabled ? null : colors.surfaceContainerHighest,
      child: InkWell(
        onTapDown: (d) => _tapAt = d.globalPosition,
        onDoubleTap: widget.onDoubleTap,
        onTap: () => widget.onTap(
          _tapAt ??
              (context.findRenderObject()! as RenderBox).localToGlobal(
                Offset.zero,
              ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: map.enabled
                        ? colors.primaryContainer
                        : colors.surfaceContainerHigh,
                    foregroundColor: map.enabled
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    child: const Icon(Icons.map_outlined),
                  ),
                  const Spacer(),
                  if (!map.enabled)
                    Chip(
                      avatar: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Disabled'),
                      visualDensity: VisualDensity.compact,
                      labelStyle: theme.textTheme.labelSmall,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                map.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Count(
                    icon: Icons.table_restaurant_outlined,
                    text: '${map.tableCount} tables',
                  ),
                  _Count(
                    icon: Icons.event_seat_outlined,
                    text: '${map.seatCount} seats',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Floats [builder]'s card with its top-left corner at [at] (global), moved
/// in to stay on screen. Tapping outside closes it with null.
Future<T?> _showFloatingAt<T>(
  BuildContext context,
  Offset at,
  WidgetBuilder builder,
) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) => CustomSingleChildLayout(
      delegate: _FloatingLayout(at),
      child: builder(context),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0).animate(animation),
        alignment: Alignment.topLeft,
        child: child,
      ),
    ),
  );
}

class _FloatingLayout extends SingleChildLayoutDelegate {
  const _FloatingLayout(this.at);

  final Offset at;

  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    at.dx.clamp(_margin, size.width - childSize.width - _margin),
    at.dy.clamp(_margin, size.height - childSize.height - _margin),
  );

  @override
  bool shouldRelayout(_FloatingLayout old) => old.at != at;
}

/// The floating card of a map's options. Disabled maps show View only in
/// place of Edit.
class _MapOptions extends StatelessWidget {
  const _MapOptions({required this.map});

  final FloorMap map;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget option(_MapAction action, IconData icon, String label) => InkWell(
      key: ValueKey('map-option-${action.name}'),
      onTap: () => Navigator.pop(context, action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: action == _MapAction.remove ? colors.error : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: action == _MapAction.remove
                  ? TextStyle(color: colors.error)
                  : null,
            ),
          ],
        ),
      ),
    );

    return Material(
      key: const ValueKey('map-options'),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: colors.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            option(_MapAction.configure, Icons.tune, 'Configure'),
            if (map.enabled)
              option(_MapAction.edit, Icons.edit_outlined, 'Edit')
            else
              option(
                _MapAction.viewOnly,
                Icons.visibility_outlined,
                'View only',
              ),
            option(_MapAction.duplicate, Icons.copy_outlined, 'Duplicate'),
            option(_MapAction.remove, Icons.delete_outline, 'Remove'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// The floating "Remove `name`?" card, with round ✓ and ✕ buttons.
class _RemoveQuestion extends StatelessWidget {
  const _RemoveQuestion({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      key: const ValueKey('remove-map-question'),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Remove "$name"?',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.error,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              key: const ValueKey('confirm-remove-map'),
              tooltip: 'Remove',
              style: IconButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              key: const ValueKey('cancel-remove-map'),
              tooltip: 'Keep',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renames a map, and enables or disables it. Returns the new name and flag,
/// or null when cancelled.
class _ConfigureDialog extends StatefulWidget {
  const _ConfigureDialog({required this.map});

  final FloorMap map;

  @override
  State<_ConfigureDialog> createState() => _ConfigureDialogState();
}

class _ConfigureDialogState extends State<_ConfigureDialog> {
  late final _name = TextEditingController(text: widget.map.name);
  late bool _enabled = widget.map.enabled;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, enabled: _enabled));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: _name,
              builder: (context, _) => TextField(
                key: const ValueKey('map-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  errorText: _name.text.trim().isEmpty ? 'Enter a name' : null,
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('map-enabled'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _enabled,
              title: const Text('Enabled'),
              subtitle: const Text('A disabled floor map can only be viewed.'),
              onChanged: (v) => setState(() => _enabled = v ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            key: const ValueKey('save-map-config'),
            onPressed: _name.text.trim().isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
