import 'package:flutter/material.dart';

/// Generic path animation widget that traces any path progressively.
/// Used for body outlines, chakra paths, and other CSV-defined paths.
class PathAnimation extends StatelessWidget {
  /// The path points to trace. If useAbsoluteCoords is false, these are
  /// normalized 0-1 coordinates. If true, these are absolute pixel coordinates.
  final List<Offset> pathPoints;
  
  /// Animation progress from 0.0 to 1.0
  final double progress;
  
  /// Stroke color for the path
  final Color strokeColor;
  
  /// Stroke width
  final double strokeWidth;
  
  /// Optional glow color (if null, no glow)
  final Color? glowColor;
  
  /// Glow blur radius
  final double glowRadius;
  
  /// Whether to show fill when animation completes
  final bool showFillOnComplete;
  
  /// Fill color (used when showFillOnComplete is true and progress >= 1.0)
  final Color? fillColor;
  
  /// Size to render the path in
  final Size? size;
  
  /// If true, pathPoints are absolute pixel coordinates (not normalized).
  /// Points will be used directly without scaling to canvas size.
  final bool useAbsoluteCoords;

  const PathAnimation({
    super.key,
    required this.pathPoints,
    required this.progress,
    this.strokeColor = Colors.white,
    this.strokeWidth = 3.0,
    this.glowColor,
    this.glowRadius = 8.0,
    this.showFillOnComplete = false,
    this.fillColor,
    this.size,
    this.useAbsoluteCoords = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size ?? Size.infinite,
      painter: _PathPainter(
        pathPoints: pathPoints,
        progress: progress,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        glowColor: glowColor,
        glowRadius: glowRadius,
        showFillOnComplete: showFillOnComplete && progress >= 1.0,
        fillColor: fillColor,
        useAbsoluteCoords: useAbsoluteCoords,
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> pathPoints;
  final double progress;
  final Color strokeColor;
  final double strokeWidth;
  final Color? glowColor;
  final double glowRadius;
  final bool showFillOnComplete;
  final Color? fillColor;
  final bool useAbsoluteCoords;

  _PathPainter({
    required this.pathPoints,
    required this.progress,
    required this.strokeColor,
    required this.strokeWidth,
    this.glowColor,
    required this.glowRadius,
    required this.showFillOnComplete,
    this.fillColor,
    this.useAbsoluteCoords = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pathPoints.isEmpty) return;

    final pointsToDraw = (pathPoints.length * progress).ceil();
    if (pointsToDraw == 0) return;
    // Scale points to canvas size
    // For absolute coordinates, use UNIFORM scaling to preserve aspect ratio
    const sourceWidth = 580.0;
    const sourceHeight = 756.0;
    
    // Calculate uniform scale factor (same as LocatingAnimation)
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY; // min without importing math
    final offsetX = (size.width - sourceWidth * scale) / 2;
    final offsetY = (size.height - sourceHeight * scale) / 2;
    
    final scaledPoints = pathPoints.take(pointsToDraw).map((p) {
      if (useAbsoluteCoords) {
        // Scale from source coordinate space with uniform scaling + centering
        return Offset(
          offsetX + p.dx * scale,
          offsetY + p.dy * scale,
        );
      } else {
        // Scale normalized 0-1 coordinates to canvas size
        return Offset(p.dx * size.width, p.dy * size.height);
      }
    }).toList();

    // Create path
    final path = Path();
    path.moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
    for (int i = 1; i < scaledPoints.length; i++) {
      path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
    }

    // Draw fill if animation complete and fill enabled
    if (showFillOnComplete && fillColor != null) {
      // Close the path for filling using same scaling as stroke
      final fullPath = Path();
      final allScaledPoints = pathPoints.map((p) {
        if (useAbsoluteCoords) {
          // Use same uniform scaling as stroke path
          return Offset(
            offsetX + p.dx * scale,
            offsetY + p.dy * scale,
          );
        } else {
          return Offset(p.dx * size.width, p.dy * size.height);
        }
      }).toList();
      fullPath.moveTo(allScaledPoints.first.dx, allScaledPoints.first.dy);
      for (int i = 1; i < allScaledPoints.length; i++) {
        fullPath.lineTo(allScaledPoints[i].dx, allScaledPoints[i].dy);
      }
      fullPath.close();
      
      // Draw glow layer first (larger, blurred)
      final glowFillPaint = Paint()
        ..color = fillColor!.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawPath(fullPath, glowFillPaint);
      
      // Draw solid fill on top (brighter)
      final fillPaint = Paint()
        ..color = fillColor!.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fullPath, fillPaint);
    }

    // Draw glow layer first
    if (glowColor != null) {
      final glowPaint = Paint()
        ..color = glowColor!.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + glowRadius
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawPath(path, glowPaint);
    }

    // Draw main stroke
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Draw animated point at end
    if (scaledPoints.isNotEmpty && progress < 1.0) {
      final endPoint = scaledPoints.last;
      
      // Pulsing dot at the end
      final dotPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, strokeWidth * 1.5, dotPaint);
      
      // Glow on dot
      if (glowColor != null) {
        final dotGlowPaint = Paint()
          ..color = glowColor!.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 1.5);
        canvas.drawCircle(endPoint, strokeWidth * 2, dotGlowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.strokeColor != strokeColor ||
           oldDelegate.pathPoints != pathPoints;
  }
}

/// Animated version of PathAnimation that handles its own animation controller
class AnimatedPathAnimation extends StatefulWidget {
  /// The path points to trace (normalized 0-1 coordinates)
  final List<Offset> pathPoints;
  
  /// Duration of the full animation
  final Duration duration;
  
  /// Stroke color for the path
  final Color strokeColor;
  
  /// Stroke width
  final double strokeWidth;
  
  /// Optional glow color (if null, no glow)
  final Color? glowColor;
  
  /// Whether to auto-start the animation
  final bool autoStart;
  
  /// Callback when animation completes
  final VoidCallback? onComplete;

  const AnimatedPathAnimation({
    super.key,
    required this.pathPoints,
    required this.duration,
    this.strokeColor = Colors.white,
    this.strokeWidth = 3.0,
    this.glowColor,
    this.autoStart = true,
    this.onComplete,
  });

  @override
  State<AnimatedPathAnimation> createState() => AnimatedPathAnimationState();
}

class AnimatedPathAnimationState extends State<AnimatedPathAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
    
    if (widget.autoStart) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Start the animation
  void start() {
    _controller.forward(from: 0);
  }

  /// Pause the animation
  void pause() {
    _controller.stop();
  }

  /// Resume the animation
  void resume() {
    _controller.forward();
  }

  /// Reset the animation
  void reset() {
    _controller.reset();
  }

  /// Get current progress
  double get progress => _animation.value;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return PathAnimation(
          pathPoints: widget.pathPoints,
          progress: _animation.value,
          strokeColor: widget.strokeColor,
          strokeWidth: widget.strokeWidth,
          glowColor: widget.glowColor,
        );
      },
    );
  }
}
