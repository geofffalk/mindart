import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animation widget for LOCATING meditation segments
/// Shows body outline with pulsing opacity, allows user to tap to select location
/// Displays growing circle at selected point
class LocatingAnimation extends StatefulWidget {
  /// Duration of the pulse animation cycle
  final Duration pulseDuration;
  
  /// Body path coordinates to display
  final List<Offset> bodyPath;
  
  /// Called when user taps to select a location
  final ValueChanged<Offset>? onLocationSelected;
  
  /// Color for the body outline
  final Color outlineColor;
  
  /// Color for the selection circle
  final Color circleColor;
  
  /// Canvas size hint for consistent scaling
  final Size? canvasSize;
  
  const LocatingAnimation({
    super.key,
    this.pulseDuration = const Duration(milliseconds: 1500),
    required this.bodyPath,
    this.onLocationSelected,
    this.outlineColor = const Color(0xFF7CB342),
    this.circleColor = Colors.white,
    this.canvasSize,
  });

  @override
  State<LocatingAnimation> createState() => _LocatingAnimationState();
}

class _LocatingAnimationState extends State<LocatingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _circleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _circleAnimation;
  
  Offset? _selectedLocation;
  
  @override
  void initState() {
    super.initState();
    
    // Pulse animation for body outline
    _pulseController = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    
    // Circle growth animation
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _circleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _circleController, curve: Curves.easeOut),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _circleController.dispose();
    super.dispose();
  }
  
  void _handleTap(TapUpDetails details) {
    if (_selectedLocation != null) return; // Only allow one selection
    
    setState(() {
      _selectedLocation = details.localPosition;
    });
    
    // Stop pulsing and start circle growth
    _pulseController.stop();
    _pulseController.value = 1.0;
    _circleController.forward();
    
    widget.onLocationSelected?.call(_selectedLocation!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _circleAnimation]),
        builder: (context, child) {
          return CustomPaint(
            painter: _LocatingPainter(
              bodyPath: widget.bodyPath,
              outlineColor: widget.outlineColor,
              circleColor: widget.circleColor,
              pulseOpacity: _selectedLocation == null ? _pulseAnimation.value : 1.0,
              selectedLocation: _selectedLocation,
              circleProgress: _circleAnimation.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _LocatingPainter extends CustomPainter {
  final List<Offset> bodyPath;
  final Color outlineColor;
  final Color circleColor;
  final double pulseOpacity;
  final Offset? selectedLocation;
  final double circleProgress;
  
  _LocatingPainter({
    required this.bodyPath,
    required this.outlineColor,
    required this.circleColor,
    required this.pulseOpacity,
    this.selectedLocation,
    required this.circleProgress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (bodyPath.isEmpty) return;
    
    // Scale body path to canvas
    const originalWidth = 580.0;
    const originalHeight = 756.0;
    final scaleX = size.width / originalWidth;
    final scaleY = size.height / originalHeight;
    final scale = math.min(scaleX, scaleY);
    final offsetX = (size.width - originalWidth * scale) / 2;
    final offsetY = (size.height - originalHeight * scale) / 2;
    
    // Draw body outline with pulsing opacity
    final outlinePaint = Paint()
      ..color = outlineColor.withOpacity(pulseOpacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Glow effect
    final glowPaint = Paint()
      ..color = outlineColor.withOpacity(pulseOpacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
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
    
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, outlinePaint);
    
    // Draw selection circle if location is selected
    if (selectedLocation != null && circleProgress > 0) {
      const circleRadius = 20.0;
      final radius = circleRadius * circleProgress;
      
      // Glow
      final circleGlowPaint = Paint()
        ..color = circleColor.withOpacity(0.5)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      // Fill
      final circleFillPaint = Paint()
        ..color = circleColor.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(selectedLocation!, radius * 1.5, circleGlowPaint);
      canvas.drawCircle(selectedLocation!, radius, circleFillPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _LocatingPainter oldDelegate) {
    return oldDelegate.pulseOpacity != pulseOpacity ||
           oldDelegate.selectedLocation != selectedLocation ||
           oldDelegate.circleProgress != circleProgress;
  }
}
