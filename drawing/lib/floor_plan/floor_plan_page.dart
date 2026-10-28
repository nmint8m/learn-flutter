import 'package:flutter/material.dart';

import 'editor/design_panel.dart';
import 'editor/design_step.dart';
import 'editor/edit_sidebar.dart';
import 'editor/floor_edits.dart';
import 'editor/palette.dart';
import 'floor_plan.dart';
import 'floor_plan_store.dart';
import 'floor_plan_view.dart';

/// The floor designer: a 3-step bar and Save in the app bar, the design panel
/// on the left, the floor in the middle, and an edit side bar on the right.
///
///   1. Room & Decor: add walls, doors, windows, plants and fixtures, and
///      select them to move or rename.
///   2. Table & Seat: the same for tables.
///   3. Review: no panel, and items can't be changed; only zoom and pan.
class FloorPlanPage extends StatefulWidget {
  const FloorPlanPage({
    super.key,
    this.repository = const JsonFileFloorPlanRepository(),
    this.actions = const [],
  });

  /// Where the plan is loaded from and saved to.
  final FloorPlanRepository repository;

  /// Extra app bar buttons, shown before Save.
  final List<Widget> actions;

  @override
  State<FloorPlanPage> createState() => _FloorPlanPageState();
}

class _FloorPlanPageState extends State<FloorPlanPage> {
  // Created once, so rebuilding the page doesn't reload the file.
  late final Future<FloorPlan> _loaded = widget.repository.load();

  /// The plan after changes. Null until the first change; until then the
  /// loaded plan is shown.
  FloorPlan? _edited;

  DesignStep _step = DesignStep.roomAndDecor;
  FloorItemRef? _selected;

  /// Move mode: zoom and pan are frozen, and dragging moves [_selected].
  bool _moving = false;

  /// Whether the right side bar for renaming [_selected] is open.
  bool _editing = false;
  bool _saving = false;

  /// The design panel sits on the left when the screen is at least this wide,
  /// and in a slide-out menu otherwise.
  static const _sidePanelMinWidth = 720.0;

  void _change(FloorPlan plan) => setState(() => _edited = plan);

  void _goToStep(DesignStep step) {
    setState(() {
      _step = step;
      _selected = null;
      _moving = false;
      _editing = false;
    });
  }

  void _onFloorTap(FloorPlan plan, Offset at) {
    final hit = hitTestItem(plan, at, tables: _step == DesignStep.tableAndSeat);
    setState(() {
      _selected = hit;
      _moving = false;
      if (hit == null) _editing = false;
    });
  }

  /// Adds a design panel item at [at] (floor units), or in the middle of the
  /// floor when [at] is null, and selects it.
  void _addItem(FloorPlan plan, PaletteItem item, [Offset? at]) {
    final result = addPaletteItem(
      plan,
      item,
      at ?? Offset(plan.width / 2, plan.height / 2),
    );
    final added = result.plan;
    setState(() {
      _edited = added;
      _selected = added.tables.length > plan.tables.length
          ? TableRef(added.tables.last.id)
          : ElementRef(added.elements.length - 1);
      _moving = false;
    });
    _showMessage('Added ${result.description}');
  }

  Future<void> _save(FloorPlan plan) async {
    setState(() {
      _saving = true;
      _moving = false;
    });
    try {
      final path = await widget.repository.save(plan);
      _showMessage('Saved to $path');
    } catch (e) {
      _showMessage('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FloorPlan>(
      future: _loaded,
      builder: (context, snapshot) {
        final plan = _edited ?? snapshot.data;
        final wide = MediaQuery.sizeOf(context).width >= _sidePanelMinWidth;
        final section = _step.section;

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: StepProgress(current: _step, onStepTapped: _goToStep),
            actions: [
              ...widget.actions,
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 12),
                child: FilledButton.icon(
                  key: const ValueKey('save'),
                  onPressed: plan == null || _saving ? null : () => _save(plan),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
          // On narrow screens the panel slides in from the left (the app bar
          // shows a menu button for it). Tapping an item closes it.
          drawer: plan == null || wide || section == null
              ? null
              : Drawer(
                  child: Builder(
                    builder: (drawerContext) => DesignPanel(
                      section: section,
                      onItemTapped: (item) {
                        Navigator.pop(drawerContext);
                        _addItem(plan, item);
                      },
                    ),
                  ),
                ),
          body: switch (snapshot) {
            AsyncSnapshot(hasError: true, :final error) => _ErrorMessage(
              error: error,
            ),
            _ when plan != null => _buildEditor(plan, wide),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }

  Widget _buildEditor(FloorPlan plan, bool wide) {
    final section = _step.section;
    final selected = _step.editable && _selected != null ? _selected : null;
    final selectedExists = selected != null && itemExists(plan, selected);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide && section != null) ...[
          SizedBox(
            width: 240,
            child: DesignPanel(
              section: section,
              onItemTapped: (item) => _addItem(plan, item),
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: FloorPlanView(
                        plan: plan,
                        selected: selectedExists ? selected : null,
                        onFloorTap: _step.editable && !_moving
                            ? (at) => _onFloorTap(plan, at)
                            : null,
                        onItemDropped: _step.editable
                            ? (item, at) => _addItem(plan, item, at)
                            : null,
                        onSelectedDrag: _moving && selectedExists
                            // _edited, not plan: several drag updates can
                            // arrive before the next rebuild.
                            ? (delta) => _change(
                                moveItem(_edited ?? plan, selected, delta),
                              )
                            : null,
                        onSelectedDragEnd: () =>
                            _change(snapItem(_edited ?? plan, selected!)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _hint(plan),
                      textAlign: TextAlign.center,
                      key: const ValueKey('hint'),
                    ),
                  ),
                ],
              ),
              if (selectedExists)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _SelectionToolbar(
                    name: itemName(plan, selected),
                    kind: itemKind(plan, selected),
                    moving: _moving,
                    editing: _editing,
                    saving: _saving,
                    onMove: () => setState(() => _moving = !_moving),
                    onEdit: () => setState(() {
                      _editing = !_editing;
                      _moving = false;
                    }),
                    onSave: () => _save(plan),
                  ),
                ),
            ],
          ),
        ),
        if (_editing && selectedExists) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 280,
            child: EditSidebar(
              key: ValueKey(selected),
              kind: itemKind(plan, selected),
              name: itemName(plan, selected),
              onNameChanged: (name) =>
                  _change(renameItem(_edited ?? plan, selected, name)),
              onClose: () => setState(() => _editing = false),
            ),
          ),
        ],
      ],
    );
  }

  String _hint(FloorPlan plan) {
    final seats = plan.tables.fold(0, (sum, t) => sum + t.seats.length);
    final counts = '${plan.tables.length} tables · $seats seats';
    if (_moving) {
      return '$counts · Drag anywhere on the floor to move the selected item. '
          'Tap Done when finished.';
    }
    return '$counts · Pinch to zoom · drag to move · '
        '${switch (_step) {
          DesignStep.roomAndDecor => 'tap a wall, door, window or fixture to select it',
          DesignStep.tableAndSeat => 'tap a table to select it',
          DesignStep.review => 'review only: items can\'t be changed',
        }}';
  }
}

/// Shown at the top right of the floor while an item is selected: the item's
/// name and the Move, Edit and Save buttons.
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.name,
    required this.kind,
    required this.moving,
    required this.editing,
    required this.saving,
    required this.onMove,
    required this.onEdit,
    required this.onSave,
  });

  final String name;
  final String kind;
  final bool moving;
  final bool editing;
  final bool saving;
  final VoidCallback onMove;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The active button (Move while moving, Edit while editing) is filled.
    Widget button({
      required Key key,
      required bool active,
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) => active
        ? FilledButton.tonalIcon(
            key: key,
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            key: key,
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                name.isEmpty ? kind : '$name · $kind',
                style: theme.textTheme.labelMedium,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button(
                  key: const ValueKey('move'),
                  active: moving,
                  icon: moving ? Icons.check : Icons.open_with,
                  label: moving ? 'Done' : 'Move',
                  onPressed: onMove,
                ),
                const SizedBox(width: 8),
                button(
                  key: const ValueKey('edit'),
                  active: editing,
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onPressed: onEdit,
                ),
                const SizedBox(width: 8),
                button(
                  key: const ValueKey('save-item'),
                  active: false,
                  icon: Icons.save_outlined,
                  label: 'Save',
                  onPressed: saving ? null : onSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final message = error is FormatException
        ? (error as FormatException).message
        : '$error';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load the floor plan.\n\n$message',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
