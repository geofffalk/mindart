import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/meditation_service.dart';
import '../models/visual_theme.dart';
import '../models/meditation.dart';
import '../widgets/meditation_card.dart';
import 'meditation_player_screen.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';
import '../services/settings_service.dart';

/// Home screen showing list of available meditations
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MeditationService _meditationService = MeditationService();
  final SettingsService _settingsService = SettingsService();
  int _selectedIndex = 0;
  late AppVisualTheme _visualTheme;

  @override
  void initState() {
    super.initState();
    _visualTheme = _settingsService.getTheme();
  }

  void _refreshTheme() {
    setState(() {
      _visualTheme = _settingsService.getTheme();
    });
  }

  @override
  Widget build(BuildContext context) {
    // If we're on settings screen, we should refresh the theme in case it was changed
    final isDark = _visualTheme == AppVisualTheme.blueNeon;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getBackgroundGradient(_visualTheme),
        ),
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.primaryDark : AppTheme.getSurfaceColor(_visualTheme),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
              // Always refresh theme when navigating
              _visualTheme = _settingsService.getTheme();
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: isDark ? AppTheme.calmBlue : AppTheme.getPrimaryColor(_visualTheme),
          unselectedItemColor: isDark ? Colors.white54 : Colors.black38,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.self_improvement),
              label: 'Meditate',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              label: 'Saved sessions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildMeditationList();
      case 1:
        return GalleryScreen(visualTheme: _visualTheme);
      case 2:
        return SettingsScreen(onThemeChanged: _refreshTheme);
      default:
        return _buildMeditationList();
    }
  }

  Widget _buildMeditationList() {
    final meditations = _meditationService.availableMeditations;
    final isDark = _visualTheme == AppVisualTheme.blueNeon;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MindArt',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Guided meditation with creative expression',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Section title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Text(
              'Choose a Meditation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Meditation list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final meditation = meditations[index];
              return MeditationCard(
                meditation: meditation,
                onTap: () => _startMeditation(meditation),
                visualTheme: _visualTheme,
              );
            },
            childCount: meditations.length,
          ),
        ),

        // Bottom padding
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  void _startMeditation(MeditationInfo meditation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MeditationPlayerScreen(
          meditationInfo: meditation,
        ),
      ),
    ).then((_) => _refreshTheme()); // Refresh theme after coming back
  }
}
