import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Advanced HSL color picker with opacity and thickness controls
class HSLColorPicker extends StatefulWidget {
  final Color initialColor;
  final double initialOpacity;
  final double initialThickness;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onThicknessChanged;
  final List<Color> recentColors;
  
  const HSLColorPicker({
    super.key,
    required this.initialColor,
    this.initialOpacity = 1.0,
    this.initialThickness = 8.0,
    required this.onColorChanged,
    required this.onOpacityChanged,
    required this.onThicknessChanged,
    this.recentColors = const [],
  });

  @override
  State<HSLColorPicker> createState() => _HSLColorPickerState();
}

class _HSLColorPickerState extends State<HSLColorPicker> {
  late HSLColor _hslColor;
  late double _opacity;
  late double _thickness;
  final TextEditingController _hexController = TextEditingController();
  double? _cachedWidth;
  
  @override
  void initState() {
    super.initState();
    _hslColor = HSLColor.fromColor(widget.initialColor);
    _opacity = widget.initialOpacity;
    _thickness = widget.initialThickness;
    _updateHexField();
  }
  
  void _updateHexField() {
    final color = _hslColor.toColor();
    _hexController.text = _colorToHex(color).toUpperCase();
  }
  
  String _colorToHex(Color color) {
    // Use normalized values and convert to 0-255 range
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    return '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }
  
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
  
  void _onHueChanged(double hue) {
    setState(() {
      _hslColor = _hslColor.withHue(hue);
      _updateHexField();
    });
    widget.onColorChanged(_hslColor.toColor());
  }
  
  void _onSaturationLightnessChanged(Offset position, Size size) {
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final lightness = 1.0 - (position.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _hslColor = _hslColor.withSaturation(saturation).withLightness(lightness);
      _updateHexField();
    });
    widget.onColorChanged(_hslColor.toColor());
  }
  
  void _onOpacityChanged(double value) {
    setState(() => _opacity = value);
    widget.onOpacityChanged(value);
  }
  
  void _onThicknessChanged(double value) {
    setState(() => _thickness = value);
    widget.onThicknessChanged(value);
  }
  
  void _onHexSubmitted(String hex) {
    try {
      final color = _hexToColor(hex);
      setState(() {
        _hslColor = HSLColor.fromColor(color);
      });
      widget.onColorChanged(color);
    } catch (_) {
      _updateHexField();
    }
  }
  
  void _selectRecentColor(Color color) {
    setState(() {
      _hslColor = HSLColor.fromColor(color);
      _updateHexField();
    });
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Saturation/Lightness square
          _buildSaturationLightnessSquare(),
          const SizedBox(height: 16),
          
          // Hue slider
          _buildHueSlider(),
          const SizedBox(height: 16),
          
          // Opacity slider
          _buildOpacitySlider(),
          const SizedBox(height: 16),
          
          // Thickness slider
          _buildThicknessSlider(),
          const SizedBox(height: 16),
          
          // Preview and hex input row
          _buildPreviewAndHexRow(),
          
          // Recent colors
          if (widget.recentColors.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRecentColors(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSaturationLightnessSquare() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 150);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _onSaturationLightnessChanged(details.localPosition, size),
          onPanStart: (details) => _onSaturationLightnessChanged(details.localPosition, size),
          onPanUpdate: (details) => _onSaturationLightnessChanged(details.localPosition, size),
          child: Container(
            height: size.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  HSLColor.fromAHSL(1, _hslColor.hue, 0, 0.5).toColor(),
                  HSLColor.fromAHSL(1, _hslColor.hue, 1, 0.5).toColor(),
                ],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent, Colors.black],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: _hslColor.saturation * size.width - 10,
                    top: (1 - _hslColor.lightness) * size.height - 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hslColor.toColor(),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHueSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hue',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            _cachedWidth = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _updateHueFromPosition(details.localPosition.dx),
              onHorizontalDragStart: (details) => _updateHueFromPosition(details.localPosition.dx),
              onHorizontalDragUpdate: (details) => _updateHueFromPosition(details.localPosition.dx),
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (_hslColor.hue / 360) * constraints.maxWidth - 6,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(51),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  void _updateHueFromPosition(double dx) {
    if (_cachedWidth == null) return;
    final hue = (dx / _cachedWidth! * 360).clamp(0.0, 360.0);
    _onHueChanged(hue);
  }
  
  Widget _buildOpacitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Opacity',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(_opacity * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: _opacity,
            onChanged: _onOpacityChanged,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.divider,
          ),
        ),
      ],
    );
  }
  
  Widget _buildThicknessSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Thickness',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_thickness.round()}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: _thickness,
            min: 1,
            max: 100,
            onChanged: _onThicknessChanged,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.divider,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPreviewAndHexRow() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _hslColor.toColor().withAlpha((_opacity * 255).round()),
            border: Border.all(color: AppTheme.divider),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: _hexController,
            decoration: InputDecoration(
              labelText: 'Hex',
              prefixText: '#',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
            onSubmitted: _onHexSubmitted,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecentColors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Colors',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.recentColors.take(8).map((color) {
            return GestureDetector(
              onTap: () => _selectRecentColor(color),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color == _hslColor.toColor() 
                        ? AppTheme.primary 
                        : AppTheme.divider,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }
}

/// Show advanced HSL color picker dialog
/// Returns a tuple of (Color, opacity, thickness)
Future<(Color, double, double)?> showAdvancedColorPicker(
  BuildContext context, {
  required Color currentColor,
  double currentOpacity = 1.0,
  double currentThickness = 8.0,
  List<Color> recentColors = const [],
}) async {
  Color selectedColor = currentColor;
  double selectedOpacity = currentOpacity;
  double selectedThickness = currentThickness;
  
  final result = await showModalBottomSheet<(Color, double, double)?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle - tap to confirm selection
            GestureDetector(
              onTap: () => Navigator.of(context).pop((selectedColor, selectedOpacity, selectedThickness)),
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              child: HSLColorPicker(
                initialColor: selectedColor,
                initialOpacity: selectedOpacity,
                initialThickness: selectedThickness,
                recentColors: recentColors,
                onColorChanged: (color) => selectedColor = color,
                onOpacityChanged: (opacity) => selectedOpacity = opacity,
                onThicknessChanged: (thickness) => selectedThickness = thickness,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
  
  // If user dismissed without explicit result, return the current selection
  return result ?? (selectedColor, selectedOpacity, selectedThickness);
}

