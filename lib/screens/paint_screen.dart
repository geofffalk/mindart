import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/brush_settings.dart';
import '../services/database_service.dart';
import '../widgets/paint_canvas.dart';
import '../widgets/hsl_color_picker.dart';
import '../widgets/audio_record_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

/// Paint screen for drawing during meditation
class PaintScreen extends StatefulWidget {
  final int meditationId;
  final String meditationTitle;
  final int sessionTime;
  final int drawingIndex;
  final String? drawingName;

  const PaintScreen({
    super.key,
    required this.meditationId,
    required this.meditationTitle,
    required this.sessionTime,
    required this.drawingIndex,
    this.drawingName,
  });

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<PaintCanvasState> _canvasKey = GlobalKey();
  final DatabaseService _databaseService = DatabaseService();
  
  BrushSettings _brushSettings = BrushSettings.forStyle(BrushStyle.pen);
  bool _isSaving = false;
  bool _isToolbarExpanded = false;
  Offset _toolbarPosition = const Offset(16, double.infinity); // Will be positioned at bottom
  double _lastScale = 1.0; // Track pinch gesture scale
  
  late AnimationController _toolbarAnimController;
  late Animation<double> _toolbarAnimation;
  Uint8List? _audioData;

  @override
  void initState() {
    super.initState();
    _toolbarAnimController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _toolbarAnimation = CurvedAnimation(
      parent: _toolbarAnimController,
      curve: Curves.easeOutCubic,
    );
    
    // Load saved color from preferences
    _loadSavedColor();
  }

  @override
  void dispose() {
    _toolbarAnimController.dispose();
    super.dispose();
  }

  
  Future<void> _loadSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('brush_color');
    if (colorValue != null) {
      setState(() {
        _brushSettings = _brushSettings.copyWith(color: Color(colorValue));
      });
      _canvasKey.currentState?.brushSettings = _brushSettings;
    }
  }
  
  Future<void> _saveColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('brush_color', color.value);
  }

  void _toggleToolbar() {
    setState(() => _isToolbarExpanded = !_isToolbarExpanded);
    if (_isToolbarExpanded) {
      _toolbarAnimController.forward();
    } else {
      _toolbarAnimController.reverse();
    }
  }

  void _onColorTap() async {
    final result = await showAdvancedColorPicker(
      context,
      currentColor: _brushSettings.color,
      currentOpacity: _brushSettings.opacity,
      currentThickness: _brushSettings.size,
    );
    if (result != null) {
      final (color, opacity, thickness) = result;
      setState(() {
        _brushSettings = _brushSettings.copyWith(
          color: color, 
          opacity: opacity,
          size: thickness,
        );
      });
      _canvasKey.currentState?.brushSettings = _brushSettings;
      _saveColor(color); // Persist color
    }
  }

  void _onRecordAudio() async {
    final result = await showDialog<Uint8List?>(
      context: context,
      builder: (context) => AudioRecordDialog(initialData: _audioData),
    );
    
    if (result != null) {
      setState(() {
        _audioData = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio note recorded')),
        );
      }
    }
  }

  void _onBrushStyleChanged(BrushStyle style) {
    setState(() {
      _brushSettings = BrushSettings.forStyle(style, color: _brushSettings.color);
    });
    _canvasKey.currentState?.currentBrushStyle = style;
  }

  void _onSizeChanged(double size) {
    setState(() {
      _brushSettings = _brushSettings.copyWith(size: size);
    });
    _canvasKey.currentState?.brushSettings = _brushSettings;
  }

  void _onOpacityChanged(double opacity) {
    setState(() {
      _brushSettings = _brushSettings.copyWith(opacity: opacity);
    });
    _canvasKey.currentState?.brushSettings = _brushSettings;
  }

  void _onUndo() {
    _canvasKey.currentState?.undo();
    // Force rebuild to show updated canvas
    setState(() {});
  }

  void _onClear() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Canvas?'),
        content: const Text('This will erase your current drawing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _canvasKey.currentState?.clear();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }


  Future<void> _onSave() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final imageData = await _canvasKey.currentState?.export();
      
      if (imageData != null) {
        await _databaseService.saveDrawing(
          meditationId: widget.meditationId,
          meditationTitle: widget.meditationTitle,
          sessionTime: widget.sessionTime,
          drawingIndex: widget.drawingIndex,
          drawingName: widget.drawingName,
          drawing: imageData,
          audio: _audioData,
        );

        if (mounted) {
          Navigator.of(context).pop((true, imageData));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save drawing')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.drawingName ?? 'Your Expression',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          // Undo button
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _onUndo,
            tooltip: 'Undo',
          ),
          // Clear button  
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _onClear,
            tooltip: 'Clear',
          ),
          // Save button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _onSave,
              icon: _isSaving 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.calmBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen paint canvas
          Positioned.fill(
            child: PaintCanvas(
              key: _canvasKey,
            ),
          ),
          // Fixed toolbar at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _buildFloatingToolbar(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    return AnimatedBuilder(
      animation: _toolbarAnimation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryDark.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expanded options (sliders)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizeTransition(
                  sizeFactor: _toolbarAnimation,
                  child: _buildExpandedOptions(),
                ),
              ),
              
              // Main toolbar row
              _buildMainToolbarRow(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainToolbarRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pen tool
          _ToolButton(
            icon: Icons.edit,
            isSelected: _brushSettings.style == BrushStyle.pen,
            onTap: () => _onBrushStyleChanged(BrushStyle.pen),
          ),
          
          // Fill tool
          _ToolButton(
            icon: Icons.format_color_fill,
            isSelected: _brushSettings.style == BrushStyle.fill,
            onTap: () => _onBrushStyleChanged(BrushStyle.fill),
          ),
          
          // Eraser tool
          _ToolButton(
            icon: Icons.auto_fix_normal,
            isSelected: _brushSettings.style == BrushStyle.eraser,
            onTap: () => _onBrushStyleChanged(BrushStyle.eraser),
          ),
          
          // Color button
          _ToolButton(
            icon: Icons.palette,
            color: _brushSettings.color,
            onTap: _onColorTap,
          ),
          
          // Audio Note button
          _ToolButton(
            icon: _audioData != null ? Icons.mic : Icons.mic_none,
            isSelected: _audioData != null,
            isSelectedColor: AppTheme.calmBlue,
            onTap: _onRecordAudio,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedOptions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // Thickness slider
          _SliderRow(
            icon: Icons.line_weight,
            label: 'Thickness',
            value: _brushSettings.size,
            min: 1,
            max: 100,
            displayValue: '${_brushSettings.size.round()}',
            onChanged: _onSizeChanged,
          ),
          const SizedBox(height: 8),
          
          // Opacity slider
          _SliderRow(
            icon: Icons.opacity,
            label: 'Opacity',
            value: _brushSettings.opacity,
            min: 0.1,
            max: 1.0,
            displayValue: '${(_brushSettings.opacity * 100).round()}%',
            onChanged: _onOpacityChanged,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final bool isSelected;
  final Color? isSelectedColor;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    this.color,
    this.isSelected = false,
    this.isSelectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isColorButton = color != null;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isColorButton 
              ? color 
              : (isSelected ? (isSelectedColor ?? AppTheme.calmBlue) : Colors.white.withValues(alpha: 0.1)),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white30,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isColorButton ? [
            BoxShadow(
              color: color!.withValues(alpha: 0.4),
              blurRadius: 8,
            ),
          ] : null,
        ),
        child: Icon(
          icon,
          color: isColorButton 
              ? _getContrastColor(color!) 
              : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: AppTheme.calmBlue,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            displayValue,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
