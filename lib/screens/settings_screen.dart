import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/settings_service.dart';
import '../models/visual_theme.dart';

/// Screen for managing user preferences and app settings
class SettingsScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  
  const SettingsScreen({
    super.key,
    this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  late String _selectedGender;
  late AppVisualTheme _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedGender = _settingsService.getGender();
    _selectedTheme = _settingsService.getTheme();
  }

  void _onGenderChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedGender = value;
      });
      _settingsService.setGender(value);
    }
  }

  void _onThemeChanged(AppVisualTheme? value) {
    if (value != null) {
      setState(() {
        _selectedTheme = value;
      });
      _settingsService.setTheme(value);
      widget.onThemeChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.getBackgroundGradient(_selectedTheme),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personalize your meditation experience',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Settings Section - Bio-Information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Biological Form',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.getPrimaryColor(_selectedTheme),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Gender Selection Container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text('Woman', style: TextStyle(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.black87)),
                      subtitle: Text('Use feminine body visualizations', style: TextStyle(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white54 : Colors.black54, fontSize: 12)),
                      value: 'woman',
                      groupValue: _selectedGender,
                      onChanged: _onGenderChanged,
                      activeColor: AppTheme.getPrimaryColor(_selectedTheme),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Divider(height: 1, color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white12 : Colors.black12),
                    RadioListTile<String>(
                      title: Text('Man', style: TextStyle(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.black87)),
                      subtitle: Text('Use masculine body visualizations', style: TextStyle(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white54 : Colors.black54, fontSize: 12)),
                      value: 'man',
                      groupValue: _selectedGender,
                      onChanged: _onGenderChanged,
                      activeColor: AppTheme.getPrimaryColor(_selectedTheme),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Settings Section - Visual Style
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Visual Style',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.getPrimaryColor(_selectedTheme),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Theme Selection Container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  children: AppVisualTheme.values.map((theme) {
                    final isLast = theme == AppVisualTheme.values.last;
                    return Column(
                      children: [
                        RadioListTile<AppVisualTheme>(
                          title: Text(theme.displayName, style: TextStyle(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.black87)),
                          subtitle: Text(_getThemeDescription(theme), style: TextStyle(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white54 : Colors.black54, fontSize: 12)),
                          value: theme,
                          groupValue: _selectedTheme,
                          onChanged: _onThemeChanged,
                          activeColor: AppTheme.getPrimaryColor(_selectedTheme),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        if (!isLast) Divider(height: 1, color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white12 : Colors.black12),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 40),

              // Version info footer
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'MindArt v2.0',
                    style: TextStyle(color: _selectedTheme == AppVisualTheme.blueNeon ? Colors.white24 : Colors.black26, fontSize: 12),
                  ),
                ),
              ),
              
              const SizedBox(height: 100), // Extra space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeDescription(AppVisualTheme theme) {
    switch (theme) {
      case AppVisualTheme.blueNeon:
        return 'Glowing lines on a dark aesthetic';
      case AppVisualTheme.sketchbook:
        return 'Hand-drawn rough lines on paper';
      case AppVisualTheme.pencil:
        return 'Fine graphite strokes and subtle shades';
      case AppVisualTheme.childlike:
        return 'Bold, bright, and playful drawings';
    }
  }
}
