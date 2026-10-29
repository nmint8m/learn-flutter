import 'package:flutter/material.dart';

import '../../geometry/geometry_shape.dart';
import 'palette.dart';

/// The vertical panel of things you can add to the floor, for one design
/// step's [section].
///
/// Drag an item onto the floor to place it there, or tap it to add it in the
/// middle of the floor.
class DesignPanel extends StatelessWidget {
  const DesignPanel({
    super.key,
    required this.section,
    required this.onItemTapped,
    this.settings = const [],
  });

  final PaletteSection section;
  final ValueChanged<PaletteItem> onItemTapped;

  /// The table types' settings, shown under "Table configuration" in the
  /// Table & Seat step: a title, a summary of the values, and what tapping
  /// does. Each is keyed `config-<key>`. Empty hides the section.
  final List<({String key, String title, String summary, VoidCallback onTap})>
  settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      for (final item in PaletteItem.values)
        if (item.section == section) item,
    ];

    // Material (not ColoredBox) so the items' tap ripples stay visible.
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(section.title, style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Drag onto the floor, or tap to add in the middle. '
              'Tap an item on the floor to move or rename it.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (section == PaletteSection.tableAndSeat)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'TABLE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
          for (final item in items)
            _PaletteTile(item: item, onTap: () => onItemTapped(item)),
          if (section == PaletteSection.tableAndSeat &&
              settings.isNotEmpty) ...[
            const Divider(height: 24, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'TABLE CONFIGURATION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
            for (final setting in settings)
              ListTile(
                key: ValueKey('config-${setting.key}'),
                dense: true,
                leading: const SizedBox.square(
                  dimension: 32,
                  child: Icon(Icons.straighten),
                ),
                title: Text(setting.title),
                subtitle: Text(setting.summary),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: setting.onTap,
              ),
          ],
        ],
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({required this.item, required this.onTap});

  final PaletteItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      key: ValueKey('palette-${item.name}'),
      dense: true,
      leading: SizedBox.square(dimension: 32, child: _PaletteIcon(item)),
      title: Text(item.label),
      trailing: const Icon(Icons.drag_indicator, size: 18),
      onTap: onTap,
    );

    // Starts only on a sideways drag (toward the floor), so dragging up and
    // down still scrolls the panel.
    return Draggable<PaletteItem>(
      data: item,
      affinity: Axis.horizontal,
      // The drop point is the finger, not the corner of the preview.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragPreview(item: item),
      child: tile,
    );
  }
}

/// What follows the finger while dragging.
class _DragPreview extends StatelessWidget {
  const _DragPreview({required this.item});

  final PaletteItem item;

  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
      // Centered on the finger.
      translation: const Offset(-0.5, -0.5),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 28, child: _PaletteIcon(item)),
              const SizedBox(width: 8),
              Text(item.label),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tables show their real shape, drawn with [GeometryShape]. Room & decor
/// items use an icon.
class _PaletteIcon extends StatelessWidget {
  const _PaletteIcon(this.item);

  final PaletteItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (item.tableShape case final shape?) {
      return Center(
        child: GeometryShape(
          size: switch (item) {
            PaletteItem.roundedRectTable => const Size(30, 16),
            PaletteItem.roundedSquareTable => const Size.square(22),
            PaletteItem.barTable => const Size(32, 10),
            _ => const Size.square(24),
          },
          pathBuilder: (rect) => shape.path(rect, 10),
          fillColor: colors.primaryContainer,
          borderColor: colors.primary,
          borderWidth: 1.5,
        ),
      );
    }

    return Icon(switch (item) {
      PaletteItem.wall => Icons.horizontal_rule,
      PaletteItem.entranceDoor => Icons.door_front_door_outlined,
      PaletteItem.window => Icons.window_outlined,
      PaletteItem.plant => Icons.local_florist_outlined,
      _ => Icons.kitchen_outlined,
    }, color: colors.onSurfaceVariant);
  }
}
