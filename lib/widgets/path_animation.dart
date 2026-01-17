import 'package:flutter/material.dart';
import '../models/visual_theme.dart';
import 'dart:math' as math;

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
  
  /// The visual theme to use for rendering
  final AppVisualTheme visualTheme;

  /// Animation style (stroke thickness/glow multiplier)
  final int animationStyle;

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
    this.animationStyle = 1,
    this.visualTheme = AppVisualTheme.blueNeon,
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
        animationStyle: animationStyle,
        visualTheme: visualTheme,
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
  final int animationStyle;
  final AppVisualTheme visualTheme;

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
    this.animationStyle = 1,
    required this.visualTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pathPoints.isEmpty) return;

    // Scaling constants
    const sourceWidth = 580.0;
    const sourceHeight = 756.0;
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = (size.width - sourceWidth * scale) / 2;
    final offsetY = (size.height - sourceHeight * scale) / 2;

    // Helper to scale points (STABLE - no jitter here)
    Offset scalePoint(Offset p) {
      if (useAbsoluteCoords) {
        return Offset(offsetX + p.dx * scale, offsetY + p.dy * scale);
      } else {
        return Offset(p.dx * size.width, p.dy * size.height);
      }
    }

    // Helper for render-time jitter
    Offset jitterPoint(Offset p, int index, AppVisualTheme theme) {
      if (theme == AppVisualTheme.sketchbook || theme == AppVisualTheme.pencil) {
        final random = math.Random(index + 100);
        // Subtle jitter for organic feel (0.5 for sketchbook, 0.4 for pencil)
        final jitterAmount = (theme == AppVisualTheme.sketchbook ? 0.5 : 0.4);
        return Offset(
          p.dx + (random.nextDouble() - 0.5) * jitterAmount,
          p.dy + (random.nextDouble() - 0.5) * jitterAmount,
        );
      } else if (theme == AppVisualTheme.childlike) {
        final random = math.Random(index ~/ 5);
        return Offset(
          p.dx + (random.nextDouble() - 0.5) * 3.0,
          p.dy + (random.nextDouble() - 0.5) * 3.0,
        );
      }
      return p;
    }

    // 1. Prepare points based on theme
    List<Offset> processedPoints;
    
    if (visualTheme == AppVisualTheme.sketchbook) {
      // PRE-DECIMATE the entire path for consistency using STABLE coordinates (no jitter yet)
      final List<Offset> decimated = [];
      decimated.add(scalePoint(pathPoints.first));
      
      Offset lastKeptStable = decimated.first;
      for (int i = 1; i < pathPoints.length - 1; i++) {
        final current = scalePoint(pathPoints[i]);
        final prev = scalePoint(pathPoints[i-1]);
        final next = scalePoint(pathPoints[i+1]);
        
        final v1 = current - prev;
        final v2 = next - current;
        
        bool keep = false;
        if (v1.distance > 0 && v2.distance > 0) {
          final dot = (v1.dx * v2.dx + v1.dy * v2.dy);
          final mags = v1.distance * v2.distance;
          final angle = math.acos((dot / mags).clamp(-1.0, 1.0));
          
          // KEEP MORE POINTS in curves to avoid gaps (angle > 0.05)
          // Also use a tighter distance cap (8px) for stable drawing
          if (angle > 0.05 || (current - lastKeptStable).distance > 8) {
            keep = true;
          } else if (i % 4 == 0) {
            // Sample straights every 4 points
            keep = true;
          }
        }
        
        if (keep) {
          decimated.add(current);
          lastKeptStable = current;
        }
      }
      decimated.add(scalePoint(pathPoints.last));
      processedPoints = decimated;
    } else {
      // Standard scaled points
      processedPoints = [];
      for (int i = 0; i < pathPoints.length; i++) {
        processedPoints.add(scalePoint(pathPoints[i]));
      }
    }

    // 2. Determine visible points based on progress
    final visibleCount = (processedPoints.length * progress).ceil();
    if (visibleCount == 0) return;
    final visiblePoints = processedPoints.sublist(0, visibleCount);

    // 3. Draw Fill
    if (showFillOnComplete && fillColor != null) {
      final fillPath = Path();
      if (processedPoints.isNotEmpty) {
        fillPath.moveTo(processedPoints.first.dx, processedPoints.first.dy);
        for (final p in processedPoints) {
          fillPath.lineTo(p.dx, p.dy);
        }
        fillPath.close();
        
        final fillPaint = Paint()
          ..color = fillColor!.withValues(alpha: visualTheme == AppVisualTheme.pencil ? 0.3 : 0.6)
          ..style = PaintingStyle.fill;
          
        if (visualTheme == AppVisualTheme.sketchbook) {
          // Layered watercolor fill
          final baseFillPaint = Paint()
            ..color = fillColor!.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill;
          canvas.drawPath(fillPath, baseFillPaint);
          final bleedPaint = Paint()
            ..color = fillColor!.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.save();
          canvas.translate(1.5, 1.0);
          canvas.drawPath(fillPath, bleedPaint);
          canvas.restore();
        } else if (visualTheme == AppVisualTheme.blueNeon) {
          final glowFill = Paint()
            ..color = fillColor!.withValues(alpha: 0.6)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
          canvas.drawPath(fillPath, glowFill);
          canvas.drawPath(fillPath, fillPaint);
        } else {
          canvas.drawPath(fillPath, fillPaint);
        }
      }
    }

    // 4. Draw Strokes
    if (visualTheme == AppVisualTheme.sketchbook) {
      final baseWidth = strokeWidth * 2.2; 
      const int segmentSize = 25; // Long segments for fluid strokes
      const int overlap = 8;
      
      for (int i = 0; i < visiblePoints.length - 1; i += (segmentSize - overlap)) {
        final random = math.Random(i + 1234);
        
        // Curvature check across the segment to ensure NO gaps on curves
        bool isCurve = false;
        final int checkEnd = math.min(i + segmentSize, processedPoints.length);
        for (int k = i + 1; k < checkEnd - 1; k++) {
          final v1 = processedPoints[k] - processedPoints[k-1];
          final v2 = processedPoints[k+1] - processedPoints[k];
          if (v1.distance > 0 && v2.distance > 0) {
             final angle = math.acos((v1.dx * v2.dx + v1.dy * v2.dy) / (v1.distance * v2.distance)).clamp(-1.0, 1.0).abs();
             if (angle > 0.08) {
               isCurve = true;
               break;
             }
          }
        }

        // 30% gap chance, but strictly forbidden on curves
        if (!isCurve && random.nextDouble() < 0.30) continue;

        final int end = math.min(i + segmentSize, visiblePoints.length);
        if (end <= i + 1) break;
        
        final segmentPath = Path();
        final pStart = jitterPoint(visiblePoints[i], i, visualTheme);
        segmentPath.moveTo(pStart.dx, pStart.dy);
        
        for (int j = i + 1; j < end; j++) {
          final p = jitterPoint(visiblePoints[j], j, visualTheme);
          segmentPath.lineTo(p.dx, p.dy);
        }

        // Taper: sinusoidal multiplier over path progress
        final double pathRatio = i / math.max(1, processedPoints.length - 1);
        final double taper = 0.35 + 0.8 * math.sin(pathRatio * math.pi);
        final pressure = taper * (0.9 + random.nextDouble() * 0.2);

        final bodyPaint = Paint()
          ..color = strokeColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseWidth * pressure
          ..strokeCap = StrokeCap.round;
          
        final corePaint = Paint()
          ..color = strokeColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseWidth * 0.4 * pressure
          ..strokeCap = StrokeCap.round;
          
        canvas.drawPath(segmentPath, bodyPaint);
        canvas.drawPath(segmentPath, corePaint);
      }
    } else {
      final path = Path();
      if (visiblePoints.isNotEmpty) {
        final p0 = jitterPoint(visiblePoints.first, 0, visualTheme);
        path.moveTo(p0.dx, p0.dy);
        for (int i = 1; i < visiblePoints.length; i++) {
          final p = jitterPoint(visiblePoints[i], i, visualTheme);
          path.lineTo(p.dx, p.dy);
        }
      }
      
      if (visualTheme == AppVisualTheme.blueNeon) {
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
        final strokePaint = Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = (animationStyle == 0) ? 2.0 : strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, strokePaint);
      } else if (visualTheme == AppVisualTheme.pencil) {
        final strokePaint = Paint()
          ..color = strokeColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.5
          ..strokeCap = StrokeCap.square;
        canvas.drawPath(path, strokePaint);
      } else if (visualTheme == AppVisualTheme.childlike) {
        final strokePaint = Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, strokePaint);
      }
    }

    // 5. Draw Animated Tip
    if (visiblePoints.isNotEmpty && progress < 1.0) {
      final tip = visiblePoints.last;
      
      if (visualTheme == AppVisualTheme.sketchbook) {
        final random = math.Random((progress * 2000).toInt()); 
        
        // Organic dot tip for Sketchbook
        final tipPaint = Paint()
          ..color = strokeColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
          
        // Draw a small solid dot at the tip
        canvas.drawCircle(tip, strokeWidth * 1.2, tipPaint);
        
        // Add subtle organic "graphite" splatters
        for (int i = 0; i < 3; i++) {
          final dx = (random.nextDouble() - 0.5) * 5.0;
          final dy = (random.nextDouble() - 0.5) * 5.0;
          final r = random.nextDouble() * 1.5;
          canvas.drawCircle(
            Offset(tip.dx + dx, tip.dy + dy), 
            r, 
            Paint()..color = strokeColor.withValues(alpha: 0.3)
          );
        }
      } else {
        // Styled default tip with ELECTRIC neon glow (for Blue Neon/Childlike)
        final tipPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
        
        if (glowColor != null) {
          final outerGlow = Paint()
            ..color = glowColor!.withValues(alpha: 0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 4.0);
          final midGlow = Paint()
            ..color = glowColor!.withValues(alpha: 0.7)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 1.5);
          final innerGlow = Paint()
            ..color = strokeColor.withValues(alpha: 0.95)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.5);
            
          canvas.drawCircle(tip, strokeWidth * 6.0, outerGlow);
          canvas.drawCircle(tip, strokeWidth * 3.0, midGlow);
          canvas.drawCircle(tip, strokeWidth * 1.8, innerGlow);
        }
        
        // Bright white core for intense neon "hot point" feel
        canvas.drawCircle(tip, strokeWidth * 1.3, tipPaint);
        canvas.drawCircle(tip, strokeWidth * 0.6, Paint()..color = Colors.cyanAccent.withValues(alpha: 0.8));
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
    this.visualTheme = AppVisualTheme.blueNeon,
  });

  /// The visual theme to use for rendering
  final AppVisualTheme visualTheme;

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
          visualTheme: widget.visualTheme,
        );
      },
    );
  }
}
