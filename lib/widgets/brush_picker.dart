import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/brush_settings.dart';

/// Brush picker widget for paint screen
class BrushPicker extends StatelessWidget {
  final BrushStyle selectedBrush;
  final ValueChanged<BrushStyle> onBrushChanged;

  const BrushPicker({
    super.key,
    required this.selectedBrush,
    required this.onBrushChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryMedium.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: BrushStyle.values.map((brush) {
          return _BrushButton(
            brush: brush,
            isSelected: brush == selectedBrush,
            onTap: () => onBrushChanged(brush),
          );
        }).toList(),
      ),
    );
  }
}

class _BrushButton extends StatelessWidget {
  final BrushStyle brush;
  final bool isSelected;
  final VoidCallback onTap;

  const _BrushButton({
    required this.brush,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.calmBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                brush.icon,
                color: isSelected ? Colors.white : Colors.white60,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                brush.displayName,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
