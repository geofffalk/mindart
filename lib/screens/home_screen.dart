import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/meditation_service.dart';
import '../widgets/meditation_card.dart';
import 'meditation_player_screen.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

/// Home screen showing list of available meditations
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MeditationService _meditationService = MeditationService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.calmBlue,
          unselectedItemColor: Colors.white54,
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
        return const GalleryScreen();
      case 2:
        return const SettingsScreen();
      default:
        return _buildMeditationList();
    }
  }

  Widget _buildMeditationList() {
    final meditations = _meditationService.availableMeditations;

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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Guided meditation with creative expression',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
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
                color: Colors.white70,
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
    );
  }
}
