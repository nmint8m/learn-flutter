import 'package:flutter/material.dart';

import 'palette.dart';

/// The four steps of designing a floor.
enum DesignStep {
  roomAndDecor('Room & decor'),
  tableAndSeat('Table & seat'),
  tableConfiguration('Table configuration'),
  review('Review');

  const DesignStep(this.label);

  final String label;

  /// The design panel items for this step, or null when there is no panel.
  PaletteSection? get section => switch (this) {
    roomAndDecor => PaletteSection.roomAndDecor,
    tableAndSeat => PaletteSection.tableAndSeat,
    tableConfiguration || review => null,
  };

  /// Whether items can be added, moved, duplicated and removed.
  bool get editable => this == roomAndDecor || this == tableAndSeat;

  /// Whether tapping an item selects it and opens its Edit panel.
  bool get selectable => this != review;

  /// Whether the items tapped are tables (else walls, doors, windows and
  /// fixtures).
  bool get selectsTables => this == tableAndSeat || this == tableConfiguration;
}

/// The step bar in the app bar: numbered steps joined by lines. Tap a step to
/// switch to it. Steps that aren't [isEnabled] are greyed out and can't be
/// tapped.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.current,
    required this.onStepTapped,
    this.isEnabled,
  });

  final DesignStep current;
  final ValueChanged<DesignStep> onStepTapped;

  /// Whether a step can be tapped. Null means every step can.
  final bool Function(DesignStep step)? isEnabled;

  bool _enabled(DesignStep step) => isEnabled?.call(step) ?? true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // When space is tight, only the current step shows its name.
        final compact = constraints.maxWidth < 480;
        // Shrinks (never grows) if even the compact bar doesn't fit.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final step in DesignStep.values) ...[
                if (step.index > 0)
                  Container(
                    width: compact ? 16 : 40,
                    height: 2,
                    color: step.index <= current.index
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                _StepChip(
                  step: step,
                  // A disabled step shows its number, not a done tick.
                  state: step == current
                      ? _StepState.current
                      : step.index < current.index && _enabled(step)
                      ? _StepState.done
                      : _StepState.upcoming,
                  showLabel: !compact || step == current,
                  onTap: _enabled(step) ? () => onStepTapped(step) : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.step,
    required this.state,
    required this.showLabel,
    required this.onTap,
  });

  final DesignStep step;
  final _StepState state;
  final bool showLabel;

  /// Null when the step is disabled.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filled = state != _StepState.upcoming;

    final chip = Semantics(
      button: true,
      enabled: onTap != null,
      selected: state == _StepState.current,
      label: 'Step ${step.index + 1}: ${step.label}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('step-${step.name}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: filled
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                foregroundColor: filled
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
                child: state == _StepState.done
                    ? const Icon(Icons.check, size: 16)
                    : Text(
                        '${step.index + 1}',
                        style: const TextStyle(fontSize: 13),
                      ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  step.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: state == _StepState.current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: state == _StepState.upcoming
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return onTap == null ? Opacity(opacity: 0.38, child: chip) : chip;
  }
}
