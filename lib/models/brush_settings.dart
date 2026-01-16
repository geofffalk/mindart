import 'package:flutter/material.dart';

/// Types of brushes available in the paint canvas
enum BrushStyle {
  pen,
  neon,
  fill,
  eraser,
}

/// Display information for brush styles
extension BrushStyleInfo on BrushStyle {
  String get displayName {
    switch (this) {
      case BrushStyle.pen:
        return 'Pen';
      case BrushStyle.neon:
        return 'Neon';
      case BrushStyle.fill:
        return 'Fill';
      case BrushStyle.eraser:
        return 'Eraser';
    }
  }

  IconData get icon {
    switch (this) {
      case BrushStyle.pen:
        return Icons.edit;
      case BrushStyle.neon:
        return Icons.auto_awesome;
      case BrushStyle.fill:
        return Icons.format_color_fill;
      case BrushStyle.eraser:
        return Icons.square;
    }
  }
  
  /// Default stroke width for this brush type
  double get defaultSize {
    switch (this) {
      case BrushStyle.pen:
        return 5.0;
      case BrushStyle.neon:
        return 6.0;
      case BrushStyle.fill:
        return 1.0; // Not used for fill
      case BrushStyle.eraser:
        return 20.0;
    }
  }
  
  /// Default opacity for this brush type
  double get defaultOpacity {
    switch (this) {
      case BrushStyle.pen:
        return 1.0;
      case BrushStyle.neon:
        return 1.0;
      case BrushStyle.fill:
        return 1.0;
      case BrushStyle.eraser:
        return 1.0;
    }
  }
  
  /// Whether this tool supports drawing strokes
  bool get isStrokeTool {
    switch (this) {
      case BrushStyle.pen:
      case BrushStyle.neon:
      case BrushStyle.eraser:
        return true;
      case BrushStyle.fill:
        return false;
    }
  }
  
  /// Get paint style configuration for this brush
  Paint getPaint(Color color, double size, double opacity) {
    final paint = Paint()
      ..color = color.withAlpha((opacity * 255).round())
      ..strokeWidth = size
      ..style = PaintingStyle.stroke;
    
    switch (this) {
      case BrushStyle.pen:
        paint.strokeCap = StrokeCap.round;
        paint.strokeJoin = StrokeJoin.round;
        break;
      case BrushStyle.neon:
        // Neon uses MaskFilter for glow effect
        paint.strokeCap = StrokeCap.round;
        paint.maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
        break;
      case BrushStyle.fill:
        // Fill uses fill style instead of stroke
        paint.style = PaintingStyle.fill;
        break;
      case BrushStyle.eraser:
        paint.strokeCap = StrokeCap.round;
        // Use white color to 'erase' on white background
        paint.color = Colors.white;
        break;
    }
    
    return paint;
  }
}

/// Immutable brush settings snapshot
class BrushSettings {
  final BrushStyle style;
  final Color color;
  final double size; // 1.0 - 100.0
  final double opacity; // 0.0 - 1.0
  
  const BrushSettings({
    required this.style,
    required this.color,
    required this.size,
    required this.opacity,
  });
  
  /// Create settings with defaults for a brush style
  factory BrushSettings.forStyle(BrushStyle style, {Color color = Colors.black}) {
    return BrushSettings(
      style: style,
      color: color,
      size: style.defaultSize,
      opacity: style.defaultOpacity,
    );
  }
  
  /// Get the configured paint for rendering
  Paint get paint => style.getPaint(color, size, opacity);
  
  BrushSettings copyWith({
    BrushStyle? style,
    Color? color,
    double? size,
    double? opacity,
  }) {
    return BrushSettings(
      style: style ?? this.style,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }
}
