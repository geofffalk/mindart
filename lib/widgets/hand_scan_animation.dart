import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Hand outline tracing animation for meditation scanning segments
/// Progressively traces the outline of a hand during body scan exercises
class HandScanAnimation extends StatefulWidget {
  /// Duration of the full scan animation
  final Duration duration;
  
  /// Whether to show right hand (false = left hand)
  final bool isRightHand;
  
  /// Color for the traced outline
  final Color traceColor;
  
  /// Width of the trace line
  final double strokeWidth;
  
  /// Called when animation completes
  final VoidCallback? onComplete;
  
  const HandScanAnimation({
    super.key,
    this.duration = const Duration(seconds: 8),
    this.isRightHand = true,
    this.traceColor = const Color(0xFF7CB342), // Sage green
    this.strokeWidth = 3.0,
    this.onComplete,
  });

  @override
  State<HandScanAnimation> createState() => _HandScanAnimationState();
}

class _HandScanAnimationState extends State<HandScanAnimation> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _HandOutlinePainter(
            progress: _controller.value,
            isRightHand: widget.isRightHand,
            traceColor: widget.traceColor,
            strokeWidth: widget.strokeWidth,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _HandOutlinePainter extends CustomPainter {
  final double progress;
  final bool isRightHand;
  final Color traceColor;
  final double strokeWidth;
  
  _HandOutlinePainter({
    required this.progress,
    required this.isRightHand,
    required this.traceColor,
    required this.strokeWidth,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final path = _createHandPath(size);
    
    // If right hand, mirror the path
    if (isRightHand) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    
    // Draw faint complete outline
    final ghostPaint = Paint()
      ..color = traceColor.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(path, ghostPaint);
    
    // Draw traced portion with glow
    final glowPaint = Paint()
      ..color = traceColor.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    final tracePaint = Paint()
      ..color = traceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Extract the portion of the path to draw based on progress
    final pathMetrics = path.computeMetrics();
    double totalLength = 0;
    for (final metric in pathMetrics) {
      totalLength += metric.length;
    }
    
    final targetLength = totalLength * progress;
    double accumulatedLength = 0;
    
    for (final metric in path.computeMetrics()) {
      if (accumulatedLength >= targetLength) break;
      
      final remainingLength = targetLength - accumulatedLength;
      final extractLength = math.min(remainingLength, metric.length);
      
      final extractedPath = metric.extractPath(0, extractLength);
      canvas.drawPath(extractedPath, glowPaint);
      canvas.drawPath(extractedPath, tracePaint);
      
      accumulatedLength += metric.length;
    }
    
    // Draw moving finger indicator at current position
    if (progress > 0 && progress < 1) {
      _drawFingerIndicator(canvas, path, progress, size);
    }
    
    if (isRightHand) {
      canvas.restore();
    }
  }
  
  void _drawFingerIndicator(Canvas canvas, Path path, double progress, Size size) {
    final pathMetrics = path.computeMetrics();
    double totalLength = 0;
    for (final metric in pathMetrics) {
      totalLength += metric.length;
    }
    
    final targetLength = totalLength * progress;
    double accumulatedLength = 0;
    
    for (final metric in path.computeMetrics()) {
      if (accumulatedLength + metric.length >= targetLength) {
        final localPosition = targetLength - accumulatedLength;
        final tangent = metric.getTangentForOffset(localPosition);
        
        if (tangent != null) {
          // Pulsing finger circle
          final pulseScale = 1.0 + 0.15 * math.sin(progress * math.pi * 20);
          final radius = 8.0 * pulseScale;
          
          final fingerPaint = Paint()
            ..color = AppTheme.accent
            ..style = PaintingStyle.fill;
          
          final fingerGlowPaint = Paint()
            ..color = AppTheme.accent.withAlpha(100)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          
          canvas.drawCircle(tangent.position, radius * 1.5, fingerGlowPaint);
          canvas.drawCircle(tangent.position, radius, fingerPaint);
        }
        break;
      }
      accumulatedLength += metric.length;
    }
  }
  
  Path _createHandPath(Size size) {
    // Hand proportions - fits in a vertical rectangle
    final handWidth = size.width * 0.5;
    final handHeight = size.height * 0.85;
    final offsetX = (size.width - handWidth) / 2;
    final offsetY = (size.height - handHeight) / 2;
    
    // Scale factors
    final sx = handWidth / 100;
    final sy = handHeight / 150;
    
    final path = Path();
    
    // Start at wrist (bottom left)
    path.moveTo(offsetX + 20 * sx, offsetY + 150 * sy);
    
    // Left side of palm up to pinky
    path.quadraticBezierTo(
      offsetX + 5 * sx, offsetY + 130 * sy,
      offsetX + 8 * sx, offsetY + 105 * sy,
    );
    
    // Pinky finger
    path.lineTo(offsetX + 5 * sx, offsetY + 85 * sy);
    path.quadraticBezierTo(
      offsetX + 3 * sx, offsetY + 70 * sy,
      offsetX + 8 * sx, offsetY + 60 * sy,
    );
    path.quadraticBezierTo(
      offsetX + 12 * sx, offsetY + 50 * sy,
      offsetX + 18 * sx, offsetY + 60 * sy,
    );
    path.lineTo(offsetX + 20 * sx, offsetY + 80 * sy);
    
    // Ring finger
    path.lineTo(offsetX + 25 * sx, offsetY + 75 * sy);
    path.quadraticBezierTo(
      offsetX + 25 * sx, offsetY + 50 * sy,
      offsetX + 32 * sx, offsetY + 38 * sy,
    );
    path.quadraticBezierTo(
      offsetX + 38 * sx, offsetY + 28 * sy,
      offsetX + 44 * sx, offsetY + 38 * sy,
    );
    path.lineTo(offsetX + 44 * sx, offsetY + 70 * sy);
    
    // Middle finger
    path.lineTo(offsetX + 48 * sx, offsetY + 65 * sy);
    path.quadraticBezierTo(
      offsetX + 48 * sx, offsetY + 35 * sy,
      offsetX + 55 * sx, offsetY + 20 * sy,
    );
    path.quadraticBezierTo(
      offsetX + 62 * sx, offsetY + 8 * sy,
      offsetX + 68 * sx, offsetY + 20 * sy,
    );
    path.lineTo(offsetX + 68 * sx, offsetY + 60 * sy);
    
    // Index finger
    path.lineTo(offsetX + 72 * sx, offsetY + 55 * sy);
    path.quadraticBezierTo(
      offsetX + 72 * sx, offsetY + 30 * sy,
      offsetX + 78 * sx, offsetY + 22 * sy,
    );
    path.quadraticBezierTo(
      offsetX + 85 * sx, offsetY + 14 * sy,
      offsetX + 90 * sx, offsetY + 25 * sy,
    );
    path.lineTo(offsetX + 88 * sx, offsetY + 60 * sy);
    
    // Gap before thumb
    path.lineTo(offsetX + 92 * sx, offsetY + 75 * sy);
    
    // Thumb
    path.quadraticBezierTo(
      offsetX + 100 * sx, offsetY + 80 * sy,
      offsetX + 100 * sx, offsetY + 95 * sy,
    );
    path.quadraticBezierTo(
      offsetX + 100 * sx, offsetY + 108 * sy,
      offsetX + 92 * sx, offsetY + 115 * sy,
    );
    path.lineTo(offsetX + 85 * sx, offsetY + 105 * sy);
    
    // Right side of palm down to wrist
    path.quadraticBezierTo(
      offsetX + 90 * sx, offsetY + 130 * sy,
      offsetX + 80 * sx, offsetY + 150 * sy,
    );
    
    // Close path at wrist
    path.close();
    
    return path;
  }
  
  @override
  bool shouldRepaint(covariant _HandOutlinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.isRightHand != isRightHand ||
           oldDelegate.traceColor != traceColor;
  }
}
