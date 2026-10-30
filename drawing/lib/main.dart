import 'package:flutter/material.dart';

import 'floor_plan/floor_maps_page.dart';
import 'geometry/geometry_shape.dart';

void main() {
  runApp(const DrawingApp());
}

class DrawingApp extends StatelessWidget {
  const DrawingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drawing',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      home: const FloorMapsPage(actions: [_OpenGalleryButton()]),
    );
  }
}

/// Opens the shape gallery from the landing page's app bar.
class _OpenGalleryButton extends StatelessWidget {
  const _OpenGalleryButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Shape gallery',
      icon: const Icon(Icons.category_outlined),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const ShapeGalleryPage()),
      ),
    );
  }
}

/// Shows every shape, with controls to change their colors and border.
class ShapeGalleryPage extends StatefulWidget {
  const ShapeGalleryPage({super.key});

  @override
  State<ShapeGalleryPage> createState() => _ShapeGalleryPageState();
}

class _ShapeGalleryPageState extends State<ShapeGalleryPage> {
  static const _palette = [
    Colors.deepPurple,
    Colors.teal,
    Colors.orange,
    Colors.pink,
    Colors.white,
    Colors.black,
  ];

  Color _fillColor = Colors.teal;
  Color _borderColor = Colors.black;
  double _borderWidth = 3;
  double _cornerRadius = 20;
  String _lastTapped = 'Tap a shape';

  void _onShapeTapped(String name) {
    setState(() => _lastTapped = 'Tapped: $name');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Geometry')),
      body: Column(
        children: [
          // Pinned above the list, so it stays visible while you scroll down
          // to tap a shape.
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _lastTapped,
              key: const Key('lastTapped'),
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildGallery(textTheme)),
        ],
      ),
    );
  }

  Widget _buildGallery(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ColorPicker(
          label: 'Fill',
          colors: _palette,
          selected: _fillColor,
          onSelected: (c) => setState(() => _fillColor = c),
        ),
        _ColorPicker(
          label: 'Border',
          colors: _palette,
          selected: _borderColor,
          onSelected: (c) => setState(() => _borderColor = c),
        ),
        _LabeledSlider(
          label: 'Border width',
          value: _borderWidth,
          max: 12,
          onChanged: (v) => setState(() => _borderWidth = v),
        ),
        _LabeledSlider(
          label: 'Corner radius',
          value: _cornerRadius,
          max: 60,
          onChanged: (v) => setState(() => _cornerRadius = v),
        ),
        const Divider(height: 32),

        Text('Rounded rectangle', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        Center(
          child: GeometryShape.roundedRect(
            key: const Key('roundedRect'),
            radius: _cornerRadius,
            size: const Size(220, 110),
            fillColor: _fillColor,
            borderColor: _borderColor,
            borderWidth: _borderWidth,
            onTap: () => _onShapeTapped('Rounded rectangle'),
            semanticLabel: 'Rounded rectangle',
          ),
        ),
        const Divider(height: 32),

        Text('Semicircles', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        _ShapeRow(
          children: [
            for (final side in SemicircleSide.values)
              _Labeled(
                label: side.name,
                child: GeometryShape.semicircle(
                  key: Key('semicircle-${side.name}'),
                  side: side,
                  // Same box for all four, so they line up in the row.
                  size: const Size.square(70),
                  fillColor: _fillColor,
                  borderColor: _borderColor,
                  borderWidth: _borderWidth,
                  onTap: () => _onShapeTapped('${side.name} semicircle'),
                  semanticLabel: '${side.name} semicircle',
                ),
              ),
          ],
        ),
        const Divider(height: 32),

        Text('Quarter circles', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        _ShapeRow(
          children: [
            for (final corner in QuarterCircleCorner.values)
              _Labeled(
                label: corner.name,
                child: GeometryShape.quarterCircle(
                  key: Key('quarter-${corner.name}'),
                  corner: corner,
                  size: const Size.square(70),
                  fillColor: _fillColor,
                  borderColor: _borderColor,
                  borderWidth: _borderWidth,
                  onTap: () => _onShapeTapped('${corner.name} quarter circle'),
                  semanticLabel: '${corner.name} quarter circle',
                ),
              ),
          ],
        ),
        const Divider(height: 32),

        Text('Put together', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        // The four quarters, each a different color, make a full circle.
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _quarter(QuarterCircleCorner.topLeft, Colors.red),
                  _quarter(QuarterCircleCorner.topRight, Colors.amber),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _quarter(QuarterCircleCorner.bottomLeft, Colors.blue),
                  _quarter(QuarterCircleCorner.bottomRight, Colors.green),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quarter(QuarterCircleCorner corner, Color color) {
    return GeometryShape.quarterCircle(
      corner: corner,
      size: const Size.square(80),
      fillColor: color,
      borderColor: _borderColor,
      borderWidth: _borderWidth,
      onTap: () => _onShapeTapped('${corner.name} piece'),
    );
  }
}

class _ShapeRow extends StatelessWidget {
  const _ShapeRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label)),
          for (final color in colors)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelected(color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade400,
                      width: color == selected ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(
          child: Slider(value: value, max: max, onChanged: onChanged),
        ),
        SizedBox(width: 32, child: Text(value.toStringAsFixed(0))),
      ],
    );
  }
}
