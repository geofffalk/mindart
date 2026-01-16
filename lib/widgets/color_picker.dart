import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Color picker widget for paint screen
class ColorPickerWidget extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPickerWidget({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
  });

  static const List<Color> _colors = [
    Colors.black,
    Colors.white,
    Color(0xFFE94560), // Red
    Color(0xFFF7B731), // Gold
    Color(0xFF4FB3BF), // Teal
    Color(0xFF9B59B6), // Purple
    Color(0xFF27AE60), // Green
    Color(0xFF3498DB), // Blue
    Color(0xFFE67E22), // Orange
    Color(0xFF1ABC9C), // Turquoise
    Color(0xFFE91E63), // Pink
    Color(0xFF5D4037), // Brown
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryMedium,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose a Color',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colors.map((color) {
              final isSelected = color == selectedColor;
              return GestureDetector(
                onTap: () {
                  // Immediately select and close - no need for separate Select button
                  Navigator.of(context).pop(color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.warmGold : Colors.white30,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: _getContrastColor(color),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Single cancel button - colors are selected immediately on tap
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Show color picker dialog
Future<Color?> showColorPicker(BuildContext context, Color currentColor) async {
  Color selectedColor = currentColor;
  
  return showDialog<Color>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: StatefulBuilder(
        builder: (context, setState) => ColorPickerWidget(
          selectedColor: selectedColor,
          onColorChanged: (color) {
            setState(() => selectedColor = color);
          },
        ),
      ),
    ),
  );
}
