import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'editor/table_settings_dialog.dart';
import 'editor/design_panel.dart';
import 'editor/design_step.dart';
import 'editor/edit_sidebar.dart';
import 'editor/floor_edits.dart';
import 'editor/palette.dart';
import 'floor_plan.dart';
import 'floor_plan_store.dart';
import 'floor_plan_view.dart';

/// The floor designer: a 4-step bar and Save in the app bar, the design panel
/// on the left, the floor in the middle, and an edit side bar on the right.
///
///   1. Room & decor: add walls, doors, windows, plants and fixtures, and
///      select them to move or rename.
///   2. Table & seat: the same for tables.
///   3. Table configuration: no panel, and the room at 30% opacity, but
///      tapping a table opens its Edit panel. Tables can't be
///      moved, duplicated or removed.
///   4. Review: no panel, and items can't be changed; only zoom and pan.
///
/// A [viewOnly] page opens on Review and stays there: steps 1 and 2 are
/// disabled and there's no Save.
class FloorPlanPage extends StatefulWidget {
  const FloorPlanPage({
    super.key,
    this.repository = const JsonFileFloorPlanRepository(),
    this.actions = const [],
    this.viewOnly = false,
    this.mapName,
  });

  /// Where the plan is loaded from and saved to.
  final FloorPlanRepository repository;

  /// Extra app bar buttons, shown before Save.
  final List<Widget> actions;

  /// Only step 3, Review, can be used.
  final bool viewOnly;

  /// Shown in the app bar, before the steps.
  final String? mapName;

  @override
  State<FloorPlanPage> createState() => _FloorPlanPageState();
}

class _FloorPlanPageState extends State<FloorPlanPage> {
  // Created once, so rebuilding the page doesn't reload the file.
  late final Future<FloorPlan> _loaded = widget.repository.load();

  /// The plan after changes. Null until the first change; until then the
  /// loaded plan is shown.
  FloorPlan? _edited;

  late DesignStep _step = widget.viewOnly
      ? DesignStep.review
      : DesignStep.roomAndDecor;

  bool _stepEnabled(DesignStep step) =>
      !widget.viewOnly || step == DesignStep.review;
  FloorItemRef? _selected;

  /// The floor's zoom and pan, shared with the zoom buttons.
  final _view = FloorViewController();

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

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

  /// The item whose "Remove item?" question is showing, if any. Kept as the
  /// item, not a flag, so selecting another item hides the question.
  FloorItemRef? _confirmingRemove;

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
    if (!_stepEnabled(step)) return;
    setState(() {
      _step = step;
      _selected = null;
      _moving = false;
      _confirmingRemove = null;
      _editing = false;
    });
    // Steps without a panel show the whole floor, fitted to the screen:
    // after the next layout, as hiding the panel changes the view's size.
    if (step.section == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _view.fit());
    }
  }

  /// A single tap selects the item under it and opens its Edit panel
  /// (outer walls have nothing to edit: they're only selected). A tap on
  /// empty floor clears the selection.
  void _onFloorTap(FloorPlan plan, Offset at) {
    final hit = hitTestItem(plan, at, tables: _step.selectsTables);
    setState(() {
      _selected = hit;
      _moving = false;
      _confirmingRemove = null;
      _editing = hit != null && canRename(hit);
    });
  }

  /// A double tap selects the item under it and starts moving it.
  ///
  /// While an item is being edited or moved, a double tap elsewhere first
  /// saves the plan and lets go of that item: on empty floor nothing else
  /// is selected; on another item, that item starts moving instead. A
  /// double tap on the item already being moved keeps it moving.
  void _onFloorDoubleTap(FloorPlan plan, Offset at) {
    final hit = hitTestItem(plan, at, tables: _step.selectsTables);
    final active = _selected != null && (_editing || _moving);
    if (hit != null && hit == _selected && _moving) return;
    if (active && hit != _selected) _save(_edited ?? plan);
    if (hit == null) {
      if (active) {
        setState(() {
          _selected = null;
          _editing = false;
          _moving = false;
          _confirmingRemove = null;
        });
      }
      return;
    }
    setState(() {
      _selected = hit;
      _moving = true;
      _editing = false;
      _confirmingRemove = null;
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
    // A new table goes inside the room, at the nearest spot that fits.
    final added = result.plan.tables.length > plan.tables.length
        ? placeTableInsideRoom(result.plan, result.plan.tables.last.id)
        : result.plan;
    setState(() {
      _edited = stickOpenings(added);
      _selected = added.tables.length > plan.tables.length
          ? TableRef(added.tables.last.id)
          : ElementRef(added.elements.length - 1);
      _moving = false;
      _confirmingRemove = null;
      // New rounded tables open straight into the Edit panel, to pick their
      // seats and turn them.
      _editing =
          item == PaletteItem.roundedRectTable ||
          item == PaletteItem.roundedSquareTable ||
          item == PaletteItem.barTable;
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
  /// The table types' settings, for the panel's Table configuration.
  List<({String key, String title, String summary, VoidCallback onTap})>
  _tableSettings(FloorPlan plan, {VoidCallback? before}) {
    String m(double meters) => formatMeters(meters);
    VoidCallback open(Future<void> Function() edit) => () {
      before?.call();
      edit();
    };
    return [
      (
        key: 'rectangle',
        title: 'Rectangle',
        summary:
            'Seat ${m(plan.rectSeatWidth)} wide × '
            '${m(plan.rectSeatDepth)} deep · buffer ${m(plan.rectBuffer)}',
        onTap: open(() => _editRectangleSettings(plan)),
      ),
      (
        key: 'square',
        title: 'Square',
        summary: 'Side ${m(plan.squareSeatWidth)}',
        onTap: open(() => _editSquareSettings(plan)),
      ),
      (
        key: 'bar',
        title: 'Bar',
        summary:
            'Per seat: ${m(plan.barSlotWidth)} wide × '
            '${m(plan.barSlotDepth)} deep',
        onTap: open(() => _editBarSlot(plan)),
      ),
      (
        key: 'circle',
        title: 'Circle',
        summary: [
          'Radius',
          for (final MapEntry(key: seats, value: r) in plan.circleRadii.entries)
            '$seats seats: ${_centimeters(r)} cm',
        ].join('\n'),
        onTap: open(() => _editCircleSettings(plan)),
      ),
      (
        key: 'quarter-circle',
        title: 'Quarter circle',
        summary: [
          'Radius',
          for (final MapEntry(key: seats, value: r)
              in plan.quarterCircleRadii.entries)
            '$seats seat${seats == 1 ? '' : 's'}: ${_centimeters(r)} cm',
        ].join('\n'),
        onTap: open(() => _editQuarterCircleSettings(plan)),
      ),
    ];
  }

  /// Applies new table settings with [apply] and says how many tables of
  /// the type ([counts]) were resized.
  void _applySettings(
    FloorPlan plan,
    String what,
    FloorPlan Function(FloorPlan) apply,
    bool Function(FloorTable) counts,
  ) {
    final changed = apply(_edited ?? plan);
    _change(changed);
    final n = changed.tables.where(counts).length;
    _showMessage(
      '$what settings applied'
      '${n == 0 ? '' : ' · $n table${n == 1 ? '' : 's'} resized'}',
    );
  }

  Future<void> _editBarSlot(FloorPlan plan) async {
    final values = await showTableSettingsDialog(
      context,
      title: 'Bar',
      description:
          'The space for one seat. Every bar uses it: a bar with 5 seats is '
          '5 × the width long and the depth deep.',
      keyPrefix: 'bar-slot',
      settings: [
        (
          key: 'width',
          label: 'Width per seat',
          value: plan.barSlotWidth,
          range: FloorPlan.barSlotWidthRange,
        ),
        (
          key: 'depth',
          label: 'Depth',
          value: plan.barSlotDepth,
          range: FloorPlan.barSlotDepthRange,
        ),
      ],
    );
    if (values == null || !mounted) return;
    _applySettings(
      plan,
      'Bar',
      (p) => setBarSlot(
        p,
        widthMeters: values['width']!,
        depthMeters: values['depth']!,
      ),
      (t) => t.bar,
    );
  }

  Future<void> _editSquareSettings(FloorPlan plan) async {
    final values = await showTableSettingsDialog(
      context,
      title: 'Square',
      description:
          'Every square table is this wide on each side, with at most one '
          'seat per side.',
      keyPrefix: 'square',
      settings: [
        (
          key: 'width',
          label: 'Width',
          value: plan.squareSeatWidth,
          range: FloorPlan.squareSeatWidthRange,
        ),
      ],
    );
    if (values == null || !mounted) return;
    _applySettings(
      plan,
      'Square',
      (p) => setSquareSettings(p, widthMeters: values['width']!),
      (t) => t.square && !t.bar,
    );
  }

  /// [meters] in whole centimeters, e.g. 0.69 → "69".
  static String _centimeters(double meters) => '${(meters * 100).round()}';

  Future<void> _editCircleSettings(FloorPlan plan) async {
    final values = await showTableSettingsDialog(
      context,
      title: 'Circle',
      description:
          'The radius of every circle table with this many seats around '
          'it, in centimeters: up to 5 cm more or less than the default. '
          'The table is twice the radius across.',
      keyPrefix: 'circle',
      unit: 'cm',
      settings: [
        for (final MapEntry(key: seats, value: r) in plan.circleRadii.entries)
          (
            key: '$seats',
            label: 'Radius, $seats seats',
            value: (r * 100).roundToDouble(),
            range: switch (FloorPlan.circleRadiusRange(seats)) {
              (final min, final max) => (
                (min * 100).roundToDouble(),
                (max * 100).roundToDouble(),
              ),
            },
          ),
      ],
    );
    if (values == null || !mounted) return;
    _applySettings(
      plan,
      'Circle',
      (p) => setCircleSettings(
        p,
        radiiMeters: {
          for (final MapEntry(:key, :value) in values.entries)
            int.parse(key): value / 100,
        },
      ),
      isSizedCircleTable,
    );
  }

  Future<void> _editQuarterCircleSettings(FloorPlan plan) async {
    final values = await showTableSettingsDialog(
      context,
      title: 'Quarter circle',
      description:
          'The radius of every quarter circle table with this many seats, '
          'in centimeters: up to 5 cm more or less than the default. The '
          'seats are spread evenly along the curve.',
      keyPrefix: 'quarter-circle',
      unit: 'cm',
      settings: [
        for (final MapEntry(key: seats, value: r)
            in plan.quarterCircleRadii.entries)
          (
            key: '$seats',
            label: 'Radius, $seats seat${seats == 1 ? '' : 's'}',
            value: (r * 100).roundToDouble(),
            range: switch (FloorPlan.quarterCircleRadiusRange(seats)) {
              (final min, final max) => (
                (min * 100).roundToDouble(),
                (max * 100).roundToDouble(),
              ),
            },
          ),
      ],
    );
    if (values == null || !mounted) return;
    _applySettings(
      plan,
      'Quarter circle',
      (p) => setQuarterCircleSettings(
        p,
        radiiMeters: {
          for (final MapEntry(:key, :value) in values.entries)
            int.parse(key): value / 100,
        },
      ),
      isSizedQuarterCircleTable,
    );
  }

  Future<void> _editRectangleSettings(FloorPlan plan) async {
    final values = await showTableSettingsDialog(
      context,
      title: 'Rectangle',
      description:
          'Sizes every rectangle table from its seats (up to 2 at each end, '
          '4 along each long side):\n'
          'width = max(seats per end × width + 2 × buffer, '
          '2 × depth + 0.2)\n'
          'length = seats per long side × width '
          '+ (seats per long side + 1) × buffer',
      keyPrefix: 'rectangle',
      settings: [
        (
          key: 'width',
          label: 'Width',
          value: plan.rectSeatWidth,
          range: FloorPlan.rectSeatWidthRange,
        ),
        (
          key: 'depth',
          label: 'Depth',
          value: plan.rectSeatDepth,
          range: FloorPlan.rectSeatDepthRange,
        ),
        (
          key: 'buffer',
          label: 'Buffer',
          value: plan.rectBuffer,
          range: FloorPlan.rectBufferRange,
        ),
      ],
    );
    if (values == null || !mounted) return;
    _applySettings(
      plan,
      'Rectangle',
      (p) => setRectangleSettings(
        p,
        widthMeters: values['width']!,
        depthMeters: values['depth']!,
        bufferMeters: values['buffer']!,
      ),
      (t) => t.shape.shape == TableShape.roundedRect && !t.bar && !t.square,
    );
  }

  void _duplicateSelected(FloorPlan plan, FloorItemRef ref) {
    var (duplicated, copy) = duplicateItem(plan, ref)!;
    // A copied table stays inside the room too.
    if (copy case TableRef(:final id)) {
      duplicated = placeTableInsideRoom(duplicated, id);
    }
    setState(() {
      _edited = stickOpenings(duplicated);
      _selected = copy;
      _moving = false;
      _confirmingRemove = null;
    });
    _showMessage('Duplicated ${_shortName(plan, ref)}');
  }

  /// The item's name, or what it is ("Door") if it has none.
  String _shortName(FloorPlan plan, FloorItemRef ref) {
    final name = itemName(plan, ref);
    return name.isEmpty ? itemKind(plan, ref).split(' · ').first : name;
  }

  void _removeSelected(FloorPlan plan, FloorItemRef ref) {
    final what = _shortName(plan, ref);
    setState(() {
      _edited = stickOpenings(removeItem(plan, ref));
      _selected = null;
      _confirmingRemove = null;
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
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.mapName case final name?) ...[
                  Flexible(
                    child: Text(
                      name,
                      key: const ValueKey('map-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
                Flexible(
                  flex: 3,
                  child: StepProgress(
                    current: _step,
                    onStepTapped: _goToStep,
                    isEnabled: _stepEnabled,
                  ),
                ),
              ],
            ),
            actions: [
              ...widget.actions,
              if (!widget.viewOnly)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 12),
                  child: FilledButton.icon(
                    key: const ValueKey('save'),
                    onPressed: plan == null || _saving
                        ? null
                        : () => _save(plan),
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
                      settings: _tableSettings(
                        plan,
                        before: () => Navigator.pop(drawerContext),
                      ),
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
    final selected = _step.selectable && _selected != null ? _selected : null;
    final selectedExists = selected != null && itemExists(plan, selected);
    // Move, Duplicate and Remove: not in Table configuration.
    final canChange = selectedExists && _step.editable;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide && section != null) ...[
          SizedBox(
            width: 240,
            child: DesignPanel(
              section: section,
              settings: _tableSettings(plan),
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
                  onMove: canChange
                      ? () => setState(() => _moving = !_moving)
                      : null,
                  onEdit: selectedExists && canRename(selected)
                      ? () => setState(() {
                          _editing = !_editing;
                          _moving = false;
                        })
                      : null,
                  onDuplicate: canChange && canDuplicateOrRemove(selected)
                      ? () => _duplicateSelected(_edited ?? plan, selected)
                      : null,
                  onSave: selectedExists && !_saving ? () => _save(plan) : null,
                  onRemove: canChange && canDuplicateOrRemove(selected)
                      ? () => setState(() {
                          _confirmingRemove = _confirmingRemove == selected
                              ? null
                              : selected;
                          _moving = false;
                        })
                      : null,
                  confirmingRemove:
                      selectedExists && _confirmingRemove == selected,
                  onConfirmRemove: () =>
                      _removeSelected(_edited ?? plan, selected!),
                  onCancelRemove: () =>
                      setState(() => _confirmingRemove = null),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FloorPlanView(
                    plan: plan,
                    selected: selectedExists ? selected : null,
                    onFloorTap: _step.selectable && !_moving
                        ? (at) => _onFloorTap(plan, at)
                        : null,
                    // Also in move mode: a double tap lets go of the item
                    // (or moves on to another one).
                    onFloorDoubleTap: _step.editable
                        ? (at) => _onFloorDoubleTap(plan, at)
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
                            // Tables can't be dragged out of the room.
                            null => moveItemInsideRoom(
                              _edited ?? plan,
                              selected,
                              delta,
                            ),
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
                    // Steps 1 and 2 fade the other step's items to 30%
                    // opacity (their own stay at 100%): tables in step 1,
                    // the room's walls, doors, windows and fixtures in
                    // step 2. Step 3 fades the room to 30% too; Review shows
                    // everything at 100%. The rulers show in every step.
                    dimTables: _step == DesignStep.roomAndDecor,
                    roomOpacity: _step.selectsTables ? 0.3 : 1,
                    showRulers: true,
                    controller: _view,
                  ),
                ),
              ),
              // Bottom bar: the hint on the left, zoom buttons on the right.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _hint(plan),
                        key: const ValueKey('hint'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Zoom is frozen while moving an item, like pinching.
                    _ZoomButtons(controller: _view, enabled: !_moving),
                  ],
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
              // Table names are in capitals; room and decor names aren't.
              capitalizeName: selected is TableRef,
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
              // Rounded rectangle and square tables: seats per side and
              // rotation.
              seatsPerSide: switch (sidedTable(plan, selected)) {
                final table? => {
                  for (final side in SeatSide.values)
                    side: seatsOnSide(table, side),
                },
                null => null,
              },
              squareTable: switch (sidedTable(plan, selected)) {
                final table? => isSquareTable(table),
                null => false,
              },
              rectangleSeats: switch (sidedTable(plan, selected)) {
                // A switched-off pair of sides shows the fewest seats it
                // could have.
                final table? when !isSquareTable(table) => (
                  long: math.max(
                    rectangleSeats(table).long,
                    minSeatsPerLongSide,
                  ),
                  ends: math.max(rectangleSeats(table).ends, minSeatsPerEnd),
                ),
                _ => null,
              },
              onRectangleSeatsChanged: ({long, ends}) => _change(
                setRectangleSeats(
                  _edited ?? plan,
                  selected,
                  long: long,
                  ends: ends,
                ),
              ),
              onSeatSideChanged: (side, {required included}) => _change(
                setSeatSide(
                  _edited ?? plan,
                  selected,
                  side,
                  included: included,
                ),
              ),
              // Rounded tables, bars and fixtures can be turned.
              rotation: itemRotation(plan, selected),
              // Bars: the number of seats. A longer bar is nudged back
              // inside the room if it would poke through a wall.
              barSeats: barTable(plan, selected)?.seats.length,
              onBarSeatsChanged: (n) {
                final current = _edited ?? plan;
                final resized = setBarSeats(current, selected, n);
                final id = (selected as TableRef).id;
                final wasInside = tableInsideRoom(
                  current,
                  current.tableById(id)!,
                );
                _change(
                  wasInside ? placeTableInsideRoom(resized, id) : resized,
                );
              },
              // Circle tables: 4, 6, 8 or 10 seats, each with its
              // diameter from the Table configuration.
              circleSeats: circleTable(plan, selected)?.seatLayout.count,
              circleRadii: plan.circleRadii,
              onCircleSeatsChanged: (n) =>
                  _change(setCircleSeats(_edited ?? plan, selected, n)),
              // Quarter circle tables: 1, 2 or 3 seats, each with its
              // radius from the Table configuration.
              quarterCircleSeats: quarterCircleTable(
                plan,
                selected,
              )?.seatLayout.count,
              quarterCircleCorner: quarterCircleTable(
                plan,
                selected,
              )?.shape.corner,
              quarterCircleRadii: plan.quarterCircleRadii,
              onQuarterCircleSeatsChanged: (n) =>
                  _change(setQuarterCircleSeats(_edited ?? plan, selected, n)),
              onRotationChanged: (degrees) =>
                  _change(rotateItem(_edited ?? plan, selected, degrees)),
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
          DesignStep.roomAndDecor => 'tap a wall, door, window or fixture to edit it, double-tap to move it',
          DesignStep.tableAndSeat => 'tap a table to edit it, double-tap to move it',
          DesignStep.tableConfiguration => 'tap a table to configure it: tables can\'t be moved here',
          DesignStep.review => 'review only: items can\'t be changed',
        }}';
  }
}

/// A fixed bar above the floor: the selected item's name on the left, and
/// the Edit, Move, Save, Duplicate and Remove buttons (icons only, names in
/// tooltips) on the right. With
/// nothing selected the name is blank and the buttons are disabled (null
/// callbacks).
///
/// Remove asks first: a "Remove item?" card floats under it, over the
/// floor, with round ✓ and ✕ buttons.
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.title,
    required this.moving,
    required this.editing,
    required this.onMove,
    required this.onEdit,
    required this.onDuplicate,
    required this.onSave,
    required this.onRemove,
    required this.confirmingRemove,
    required this.onConfirmRemove,
    required this.onCancelRemove,
  });

  final String title;
  final bool moving;
  final bool editing;
  final VoidCallback? onMove;

  /// Null also for items without a name (outer walls).
  final VoidCallback? onEdit;

  /// Null also for outer walls, which can't be copied or removed.
  final VoidCallback? onDuplicate;
  final VoidCallback? onSave;
  final VoidCallback? onRemove;

  /// Whether the "Remove item?" question is showing.
  final bool confirmingRemove;
  final VoidCallback onConfirmRemove;
  final VoidCallback onCancelRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => _buildBar(theme, constraints.maxWidth),
    );
  }

  Widget _buildBar(ThemeData theme, double width) {
    final colors = theme.colorScheme;

    // Icon-only buttons; the name shows as a tooltip. The active button
    // (Move while moving, Edit while editing, Remove while asking) is
    // filled. [color] tints the button (Remove: red).
    Widget button({
      required Key key,
      required bool active,
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
      Color? color,
    }) {
      final filled = active && onPressed != null;
      const size = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(48, 40)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      );
      final tint = color == null
          ? null
          : filled
          ? FilledButton.styleFrom(
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
            )
          : OutlinedButton.styleFrom(
              foregroundColor: color,
              side: onPressed == null ? null : BorderSide(color: color),
            );
      final style = tint?.merge(size) ?? size;
      return Tooltip(
        message: label,
        child: filled
            ? FilledButton.tonal(
                key: key,
                style: style,
                onPressed: onPressed,
                child: Icon(icon),
              )
            : OutlinedButton(
                key: key,
                style: style,
                onPressed: onPressed,
                child: Icon(icon),
              ),
      );
    }

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
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
                // Shrinks to fit if even the icons don't (a very narrow
                // bar), rather than overflowing. Always as tall as a button,
                // so the bar (and the floor below) never changes height.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.max(0, width - 32),
                    minHeight: 48,
                    maxHeight: 48,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        button(
                          key: const ValueKey('edit'),
                          active: editing,
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onPressed: onEdit,
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
                          key: const ValueKey('save-item'),
                          active: false,
                          icon: Icons.save_outlined,
                          label: 'Save',
                          onPressed: onSave,
                        ),
                        // Splits the buttons that change how the item is
                        // edited and saved from those that add or remove
                        // items.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            key: const ValueKey('bar-separator'),
                            height: 28,
                            child: VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: colors.outlineVariant,
                            ),
                          ),
                        ),
                        button(
                          key: const ValueKey('duplicate'),
                          active: false,
                          icon: Icons.copy_outlined,
                          label: 'Duplicate',
                          onPressed: onDuplicate,
                        ),
                        const SizedBox(width: 8),
                        _RemoveQuestion(
                          showing: confirmingRemove,
                          onConfirm: onConfirmRemove,
                          onCancel: onCancelRemove,
                          child: button(
                            key: const ValueKey('remove-item'),
                            active: confirmingRemove,
                            icon: Icons.delete_outline,
                            label: 'Remove',
                            onPressed: onRemove,
                            color: colors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Floats a "Remove item?" card with round ✓ and ✕ buttons under [child]
/// (the Remove button) while [showing], above everything else, so the
/// floor below doesn't move.
class _RemoveQuestion extends StatefulWidget {
  const _RemoveQuestion({
    required this.showing,
    required this.onConfirm,
    required this.onCancel,
    required this.child,
  });

  final bool showing;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final Widget child;

  @override
  State<_RemoveQuestion> createState() => _RemoveQuestionState();
}

class _RemoveQuestionState extends State<_RemoveQuestion> {
  final _link = LayerLink();
  final _portal = OverlayPortalController()..show();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        if (!widget.showing) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            // Its top-right corner just under the button's bottom-right.
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 150),
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: 0.9 + 0.1 * t,
                  alignment: Alignment.topRight,
                  child: child,
                ),
              ),
              child: Material(
                key: const ValueKey('remove-question'),
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: colors.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Remove item?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        key: const ValueKey('confirm-remove'),
                        tooltip: 'Remove',
                        style: IconButton.styleFrom(
                          backgroundColor: colors.error,
                          foregroundColor: colors.onError,
                        ),
                        icon: const Icon(Icons.check),
                        onPressed: widget.onConfirm,
                      ),
                      const SizedBox(width: 4),
                      IconButton.outlined(
                        key: const ValueKey('cancel-remove'),
                        tooltip: 'Keep',
                        icon: const Icon(Icons.close),
                        onPressed: widget.onCancel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(link: _link, child: widget.child),
    );
  }
}

/// Zoom out, the zoom level, and zoom in.
class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.controller, required this.enabled});

  final FloorViewController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('zoom-out'),
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
            onPressed: enabled && controller.canZoomOut
                ? controller.zoomOut
                : null,
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${(controller.scale * 100).round()}%',
              key: const ValueKey('zoom-level'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          IconButton(
            key: const ValueKey('zoom-in'),
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
            onPressed: enabled && controller.canZoomIn
                ? controller.zoomIn
                : null,
          ),
        ],
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
