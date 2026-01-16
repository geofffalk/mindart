import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animation widget for OPENING meditation segments
/// Shows body outline with a pulsing/scaling circle at the user's selected location
class OpeningAnimation extends StatefulWidget {
  /// Duration of one pulse cycle
  final Duration pulseDuration;
  
  /// Body path coordinates to display
  final List<Offset> bodyPath;
  
  /// The user-selected location from LOCATING segment
  final Offset userLocation;
  
  /// Color for the body outline
  final Color outlineColor;
  
  /// Color for the pulsing circle
  final Color circleColor;
  
  const OpeningAnimation({
    super.key,
    this.pulseDuration = const Duration(milliseconds: 800),
    required this.bodyPath,
    required this.userLocation,
    this.outlineColor = const Color(0xFF7CB342),
    this.circleColor = Colors.white,
  });

  @override
  State<OpeningAnimation> createState() => _OpeningAnimationState();
}

class _OpeningAnimationState extends State<OpeningAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _alphaAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    );
    
    // Scale oscillates between 0.85 and 1.15
    _scaleAnimation = Tween<double>(begin: 1.15, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Alpha fades between 0.5 and 1.0
    _alphaAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          painter: _OpeningPainter(
            bodyPath: widget.bodyPath,
            outlineColor: widget.outlineColor,
            circleColor: widget.circleColor,
            userLocation: widget.userLocation,
            circleScale: _scaleAnimation.value,
            circleAlpha: _alphaAnimation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _OpeningPainter extends CustomPainter {
  final List<Offset> bodyPath;
  final Color outlineColor;
  final Color circleColor;
  final Offset userLocation;
  final double circleScale;
  final double circleAlpha;
  
  _OpeningPainter({
    required this.bodyPath,
    required this.outlineColor,
    required this.circleColor,
    required this.userLocation,
    required this.circleScale,
    required this.circleAlpha,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Scale body path to canvas
    const originalWidth = 580.0;
    const originalHeight = 756.0;
    final scaleX = size.width / originalWidth;
    final scaleY = size.height / originalHeight;
    final scale = math.min(scaleX, scaleY);
    final offsetX = (size.width - originalWidth * scale) / 2;
    final offsetY = (size.height - originalHeight * scale) / 2;
    
    // Draw body outline
    if (bodyPath.isNotEmpty) {
      final outlinePaint = Paint()
        ..color = outlineColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      
      final path = Path();
      for (int i = 0; i < bodyPath.length; i++) {
        final x = offsetX + bodyPath[i].dx * scale;
        final y = offsetY + bodyPath[i].dy * scale;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, outlinePaint);
    }
    // Circle removed - pulsing drawing overlay handles this separately
  }
  
  @override
  bool shouldRepaint(covariant _OpeningPainter oldDelegate) {
    return oldDelegate.circleScale != circleScale ||
           oldDelegate.circleAlpha != circleAlpha ||
           oldDelegate.userLocation != userLocation;
  }
}
