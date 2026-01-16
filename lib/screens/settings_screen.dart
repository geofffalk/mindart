import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/settings_service.dart';

/// Screen for managing user preferences and app settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  late String _selectedGender;

  @override
  void initState() {
    super.initState();
    _selectedGender = _settingsService.getGender();
  }

  void _onGenderChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedGender = value;
      });
      _settingsService.setGender(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Personalize your meditation experience',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
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
              color: AppTheme.calmBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Gender Selection Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text('Woman', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Use feminine body visualizations', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: 'woman',
                groupValue: _selectedGender,
                onChanged: _onGenderChanged,
                activeColor: AppTheme.calmBlue,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              RadioListTile<String>(
                title: const Text('Man', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Use masculine body visualizations', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: 'man',
                groupValue: _selectedGender,
                onChanged: _onGenderChanged,
                activeColor: AppTheme.calmBlue,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Version info footer
        const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'MindArt v2.0',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
