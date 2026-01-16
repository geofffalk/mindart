import 'dart:ui' as ui;
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import '../models/brush_settings.dart';


/// A single stroke/path drawn on the canvas
class DrawnPath {
  final List<Offset> points;
  final BrushSettings settings;

  DrawnPath({
    required this.points,
    required this.settings,
  });

  Paint get paint => settings.paint;
}

/// Represents a flood fill operation
class FillOperation {
  final Offset point;
  final Color color;
  final double opacity;
  
  FillOperation({
    required this.point,
    required this.color,
    required this.opacity,
  });
}

/// Custom painter for drawing on canvas
class PaintCanvasPainter extends CustomPainter {
  final List<DrawnPath> paths;
  final List<FillOperation> fills;
  final DrawnPath? currentPath;
  final ui.Image? fillMask;

  PaintCanvasPainter({
    required this.paths,
    required this.fills,
    this.currentPath,
    this.fillMask,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw fill mask if exists (flood fills are pre-rendered)
    if (fillMask != null) {
      canvas.drawImage(fillMask!, Offset.zero, Paint());
    }
    
    // Draw all completed paths
    for (final path in paths) {
      _drawPath(canvas, path);
    }
    
    // Draw current path being drawn
    if (currentPath != null) {
      _drawPath(canvas, currentPath!);
    }
  }

  void _drawPath(Canvas canvas, DrawnPath drawnPath) {
    if (drawnPath.points.isEmpty) return;
    
    final path = Path();
    path.moveTo(drawnPath.points.first.dx, drawnPath.points.first.dy);
    
    for (int i = 1; i < drawnPath.points.length; i++) {
      path.lineTo(drawnPath.points[i].dx, drawnPath.points[i].dy);
    }
    
    canvas.drawPath(path, drawnPath.paint);
  }

  @override
  bool shouldRepaint(covariant PaintCanvasPainter oldDelegate) {
    return oldDelegate.paths != paths || 
           oldDelegate.currentPath != currentPath ||
           oldDelegate.fills != fills ||
           oldDelegate.fillMask != fillMask;
  }
}

/// Interactive painting canvas widget
class PaintCanvas extends StatefulWidget {
  final Color backgroundColor;
  final void Function(Uint8List imageData)? onExport;

  const PaintCanvas({
    super.key,
    this.backgroundColor = Colors.white,
    this.onExport,
  });

  @override
  State<PaintCanvas> createState() => PaintCanvasState();
}

class PaintCanvasState extends State<PaintCanvas> {
  final List<DrawnPath> _paths = [];
  final List<FillOperation> _fills = [];
  DrawnPath? _currentPath;
  BrushSettings _brushSettings = BrushSettings.forStyle(BrushStyle.pen);
  final GlobalKey _canvasKey = GlobalKey();
  ui.Image? _fillMask;
  Size? _canvasSize;
  
  // Zoom/pan state
  final TransformationController _transformationController = TransformationController();
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  bool _isZoomed = false;

  /// Currently selected brush settings
  BrushSettings get brushSettings => _brushSettings;
  set brushSettings(BrushSettings settings) => setState(() => _brushSettings = settings);

  /// Currently selected color (convenience accessor)
  Color get currentColor => _brushSettings.color;
  set currentColor(Color color) => setState(() {
    _brushSettings = _brushSettings.copyWith(color: color);
  });

  /// Currently selected brush style (convenience accessor)
  BrushStyle get currentBrushStyle => _brushSettings.style;
  set currentBrushStyle(BrushStyle style) => setState(() {
    _brushSettings = _brushSettings.copyWith(style: style, size: style.defaultSize);
  });

  /// Clear the canvas
  void clear() {
    setState(() {
      _paths.clear();
      _fills.clear();
      _currentPath = null;
      _fillMask = null;
    });
  }

  /// Undo last stroke or fill
  void undo() {
    setState(() {
      if (_paths.isNotEmpty) {
        _paths.removeLast();
      } else if (_fills.isNotEmpty) {
        _fills.removeLast();
        _regenerateFillMask();
      }
    });
  }

  /// Export canvas as PNG bytes
  Future<Uint8List?> export() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() 
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error exporting canvas: $e');
      return null;
    }
  }

  void _onTapUp(TapUpDetails details) {
    // Handle fill tool taps
    if (_brushSettings.style == BrushStyle.fill) {
      _performFloodFill(details.localPosition);
    }
  }

  void _onPanStart(DragStartDetails details) {
    // Don't draw with fill tool - it uses taps
    if (_brushSettings.style == BrushStyle.fill) return;
    
    setState(() {
      _currentPath = DrawnPath(
        points: [details.localPosition],
        settings: _brushSettings,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Don't draw with fill tool
    if (_brushSettings.style == BrushStyle.fill) return;
    
    if (_currentPath != null) {
      setState(() {
        // Create a new DrawnPath with updated points to ensure repaint
        _currentPath = DrawnPath(
          points: [..._currentPath!.points, details.localPosition],
          settings: _currentPath!.settings,
        );
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPath != null) {
      setState(() {
        _paths.add(_currentPath!);
        _currentPath = null;
      });
    }
  }

  /// Perform flood fill at the given point using scanline algorithm
  Future<void> _performFloodFill(Offset point) async {
    if (_canvasSize == null) return;
    
    final width = _canvasSize!.width.toInt();
    final height = _canvasSize!.height.toInt();
    final x = point.dx.toInt();
    final y = point.dy.toInt();
    
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    
    // Capture current canvas state
    final boundary = _canvasKey.currentContext?.findRenderObject() 
        as RenderRepaintBoundary?;
    if (boundary == null) return;
    
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;
    
    final pixels = byteData.buffer.asUint8List();
    final imgWidth = image.width;
    final imgHeight = image.height;
    
    // Get target color at tap point
    final startIdx = (y * imgWidth + x) * 4;
    if (startIdx < 0 || startIdx >= pixels.length - 3) return;
    
    final targetR = pixels[startIdx];
    final targetG = pixels[startIdx + 1];
    final targetB = pixels[startIdx + 2];
    final targetA = pixels[startIdx + 3];
    
    // Fill color with opacity
    final fillColor = _brushSettings.color.withAlpha((_brushSettings.opacity * 255).round());
    final fillR = fillColor.red;
    final fillG = fillColor.green;
    final fillB = fillColor.blue;
    final fillA = fillColor.alpha;
    
    // Don't fill if clicking on same color
    if (targetR == fillR && targetG == fillG && targetB == fillB && targetA == fillA) {
      return;
    }
    
    // Scanline flood fill algorithm
    final visited = List.filled(imgWidth * imgHeight, false);
    final stack = Queue<int>();
    stack.add(y * imgWidth + x);
    
    bool matchesTarget(int idx) {
      if (idx < 0 || idx >= pixels.length ~/ 4) return false;
      final i = idx * 4;
      // Allow tolerance for antialiased edges
      final dr = (pixels[i] - targetR).abs();
      final dg = (pixels[i + 1] - targetG).abs();
      final db = (pixels[i + 2] - targetB).abs();
      final da = (pixels[i + 3] - targetA).abs();
      return dr < 30 && dg < 30 && db < 30 && da < 50;
    }
    
    while (stack.isNotEmpty) {
      final idx = stack.removeFirst();
      if (idx < 0 || idx >= imgWidth * imgHeight) continue;
      if (visited[idx]) continue;
      if (!matchesTarget(idx)) continue;
      
      visited[idx] = true;
      final py = idx ~/ imgWidth;
      final px = idx % imgWidth;
      
      // Fill this pixel
      final i = idx * 4;
      pixels[i] = fillR;
      pixels[i + 1] = fillG;
      pixels[i + 2] = fillB;
      pixels[i + 3] = fillA;
      
      // Add neighbors
      if (px > 0) stack.add(idx - 1);
      if (px < imgWidth - 1) stack.add(idx + 1);
      if (py > 0) stack.add(idx - imgWidth);
      if (py < imgHeight - 1) stack.add(idx + imgWidth);
    }
    
    // Create new image from modified pixels
    final codec = await ui.instantiateImageCodec(
      await _createPngFromRgba(pixels, imgWidth, imgHeight),
    );
    final frame = await codec.getNextFrame();
    
    setState(() {
      _fills.add(FillOperation(
        point: point,
        color: _brushSettings.color,
        opacity: _brushSettings.opacity,
      ));
      _fillMask = frame.image;
    });
  }
  
  Future<Uint8List> _createPngFromRgba(Uint8List rgba, int width, int height) async {
    // Convert RGBA to PNG using ui.Image
    final completer = ui.PictureRecorder();
    final canvas = Canvas(completer);
    
    // Create image descriptor
    final descriptor = ui.ImageDescriptor.raw(
      await ui.ImmutableBuffer.fromUint8List(rgba),
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    
    canvas.drawImage(frame.image, Offset.zero, Paint());
    final picture = completer.endRecording();
    final img = await picture.toImage(width, height);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
  
  void _regenerateFillMask() async {
    // TODO: Regenerate fill mask from _fills list
    // For now, just clear the mask when fills are undone
    _fillMask = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        return RepaintBoundary(
          key: _canvasKey,
          child: GestureDetector(
            onTapUp: _onTapUp,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: PaintCanvasPainter(
                    paths: _paths,
                    fills: _fills,
                    currentPath: _currentPath,
                    fillMask: _fillMask,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
