import 'package:flutter/material.dart';

import 'palette.dart';

/// The three steps of designing a floor.
enum DesignStep {
  roomAndDecor('Room & Decor'),
  tableAndSeat('Table & Seat'),
  review('Review');

  const DesignStep(this.label);

  final String label;

  /// The design panel items for this step, or null when there is no panel.
  PaletteSection? get section => switch (this) {
    roomAndDecor => PaletteSection.roomAndDecor,
    tableAndSeat => PaletteSection.tableAndSeat,
    review => null,
  };

  /// Whether items can be added, selected, moved and edited.
  bool get editable => this != review;
}

/// The step bar in the app bar: numbered steps joined by lines. Tap a step to
/// switch to it.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.current,
    required this.onStepTapped,
  });

  final DesignStep current;
  final ValueChanged<DesignStep> onStepTapped;

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
                  state: step == current
                      ? _StepState.current
                      : step.index < current.index
                      ? _StepState.done
                      : _StepState.upcoming,
                  showLabel: !compact || step == current,
                  onTap: () => onStepTapped(step),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filled = state != _StepState.upcoming;

    return Semantics(
      button: true,
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
  }
}
