import 'dart:math' as math;

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

  /// While dragging in move mode: the wall end being dragged, or null when
  /// the whole item is being moved.
  WallEnd? _draggedEnd;

  /// While dragging a door or window in move mode: where the finger has
  /// taken it, before sticking it to the nearest wall. Kept separately so
  /// the door can leave its wall for a nearer one: sticking after every
  /// small step would always pull it back.
  Offset? _openingDragPoint;

  /// The loaded plan, with doors and windows stuck to walls. Worked out once
  /// per load.
  FloorPlan? _loadedRaw;
  FloorPlan? _loadedStuck;

  FloorPlan _stuckLoaded(FloorPlan raw) {
    if (!identical(raw, _loadedRaw)) {
      _loadedRaw = raw;
      _loadedStuck = stickOpenings(raw);
    }
    return _loadedStuck!;
  }

  /// Whether the right side bar for renaming [_selected] is open.
  bool _editing = false;
  bool _saving = false;

  /// The design panel sits on the left when the screen is at least this wide,
  /// and in a slide-out menu otherwise.
  static const _sidePanelMinWidth = 720.0;

  /// Every change goes through here, so the rule always holds: a door or
  /// window is never left off a wall (e.g. after its wall moves).
  void _change(FloorPlan plan) => setState(() => _edited = stickOpenings(plan));

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
      _edited = stickOpenings(added);
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

  void _showMessage(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: action,
          duration: Duration(seconds: action == null ? 3 : 5),
        ),
      );
  }

  /// Removes the selected item, closes the side bar, and offers Undo.
  void _removeSelected(FloorPlan plan, FloorItemRef ref) {
    final name = itemName(plan, ref);
    final what = name.isEmpty ? itemKind(plan, ref).split(' · ').first : name;
    setState(() {
      _edited = stickOpenings(removeItem(plan, ref));
      _selected = null;
      _editing = false;
      _moving = false;
    });
    _showMessage(
      'Removed $what',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => setState(() {
          _edited = plan;
          _selected = ref;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FloorPlan>(
      future: _loaded,
      builder: (context, snapshot) {
        final plan =
            _edited ??
            (snapshot.data == null ? null : _stuckLoaded(snapshot.data!));
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
          child: Column(
            children: [
              // Fixed above the floor (and its rulers): the selected item's
              // name and its buttons, disabled while nothing is selected.
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: _SelectionToolbar(
                  title: selectedExists ? _selectionTitle(plan, selected) : '',
                  moving: _moving,
                  editing: _editing,
                  onMove: selectedExists
                      ? () => setState(() => _moving = !_moving)
                      : null,
                  onEdit: selectedExists && canRename(selected)
                      ? () => setState(() {
                          _editing = !_editing;
                          _moving = false;
                        })
                      : null,
                  onSave: selectedExists && !_saving ? () => _save(plan) : null,
                ),
              ),
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
                    // A drag that starts on a wall's start or end point
                    // moves just that end; anywhere else moves the item.
                    // A door or window follows the finger along the
                    // walls, onto whichever wall is nearest.
                    onSelectedDragStart: (at, touchRadius) {
                      final current = _edited ?? plan;
                      _draggedEnd = wallEndAt(
                        current,
                        selected!,
                        at,
                        touchRadius,
                      );
                      _openingDragPoint = switch (selected) {
                        ElementRef(:final index)
                            when current.elements[index] is OpeningElement =>
                          (current.elements[index] as OpeningElement).center,
                        _ => null,
                      };
                    },
                    onSelectedDrag: _moving && selectedExists
                        // _edited, not plan: several drag updates can
                        // arrive before the next rebuild.
                        ? (delta) => _change(switch (_draggedEnd) {
                            _ when _openingDragPoint != null => placeOpening(
                              _edited ?? plan,
                              (selected as ElementRef).index,
                              _openingDragPoint = _openingDragPoint! + delta,
                            ),
                            final end? => moveWallEnd(
                              _edited ?? plan,
                              selected,
                              end,
                              delta,
                            ),
                            null => moveItem(_edited ?? plan, selected, delta),
                          })
                        : null,
                    onSelectedDragEnd: () {
                      final current = _edited ?? plan;
                      _change(switch (_draggedEnd) {
                        final end? => snapWallEnd(current, selected!, end),
                        null => snapItem(current, selected!),
                      });
                      _draggedEnd = null;
                      _openingDragPoint = null;
                    },
                    // Step 1 is about the room: tables are hidden and
                    // rulers help place walls and decor.
                    showTables: _step != DesignStep.roomAndDecor,
                    showRulers: _step == DesignStep.roomAndDecor,
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
        ),
        if (_editing && selectedExists && canRename(selected)) ...[
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
              onRemove: () => _removeSelected(_edited ?? plan, selected),
              lengthMeters: itemLengthMeters(plan, selected),
              // Doors and windows: which wall they're on.
              walls: switch (selected) {
                ElementRef(:final index)
                    when plan.elements[index] is OpeningElement =>
                  [
                    for (final w in wallSegments(plan))
                      (id: w.id, name: w.name),
                  ],
                _ => null,
              },
              wallId: switch (selected) {
                ElementRef(:final index) => openingWall(plan, index)?.id,
                _ => null,
              },
              onWallChanged: (id) {
                if (selected case ElementRef(:final index)) {
                  final current = _edited ?? plan;
                  final wall = wallSegments(current)
                      .firstWhere((w) => w.id == id);
                  _change(
                    placeOpening(
                      current,
                      index,
                      (current.elements[index] as OpeningElement).center,
                      wall: wall,
                      round: true,
                    ),
                  );
                }
              },
              onLengthChanged: (meters) =>
                  _change(resizeItem(_edited ?? plan, selected, meters)),
              // Fixtures: width and height (or a diameter for plants), up
              // to the floor's size.
              sizeMeters: itemSizeMeters(plan, selected),
              maxSizeMeters:
                  math.max(plan.width, plan.height) * plan.metersPerUnit,
              onSizeChanged: ({width, height}) => _change(
                resizeFixture(
                  _edited ?? plan,
                  selected,
                  width: width,
                  height: height,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _selectionTitle(FloorPlan plan, FloorItemRef selected) {
    final name = itemName(plan, selected);
    final kind = itemKind(plan, selected);
    return name.isEmpty ? kind : '$name · $kind';
  }

  String _hint(FloorPlan plan) {
    final seats = plan.tables.fold(0, (sum, t) => sum + t.seats.length);
    final counts = '${plan.tables.length} tables · $seats seats';
    if (_moving) {
      final isWall =
          _selected != null &&
          itemExists(plan, _selected!) &&
          wallPoints(plan, _selected!) != null;
      final isOpening = switch (_selected) {
        ElementRef(:final index) =>
          index < plan.elements.length &&
              plan.elements[index] is OpeningElement,
        _ => false,
      };
      if (isOpening) {
        return '$counts · Drag to slide it along the walls: it sticks to the '
            'nearest wall. Tap Done when finished.';
      }
      return isWall
          ? '$counts · Drag the Start or End point to move that end, or drag '
                'anywhere else to move the whole wall. Tap Done when finished.'
          : '$counts · Drag anywhere on the floor to move the selected item. '
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

/// A fixed bar above the floor: the selected item's name on the left, and
/// the Move, Edit and Save buttons on the right. With nothing selected the
/// name is blank and the buttons are disabled (null callbacks).
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.title,
    required this.moving,
    required this.editing,
    required this.onMove,
    required this.onEdit,
    required this.onSave,
  });

  final String title;
  final bool moving;
  final bool editing;
  final VoidCallback? onMove;

  /// Null also for items without a name (outer walls).
  final VoidCallback? onEdit;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow (e.g. with the Edit side bar open): icons only.
        final compact = constraints.maxWidth < 560;
        return _buildBar(theme, compact);
      },
    );
  }

  Widget _buildBar(ThemeData theme, bool compact) {
    // The active button (Move while moving, Edit while editing) is filled.
    Widget button({
      required Key key,
      required bool active,
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) {
      final filled = active && onPressed != null;
      if (compact) {
        return Tooltip(
          message: label,
          child: filled
              ? FilledButton.tonal(
                  key: key,
                  onPressed: onPressed,
                  child: Icon(icon),
                )
              : OutlinedButton(
                  key: key,
                  onPressed: onPressed,
                  child: Icon(icon),
                ),
        );
      }
      return filled
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
    }

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                key: const ValueKey('selection-title'),
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
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
              onPressed: onSave,
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
