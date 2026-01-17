import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../config/theme.dart';
import '../models/saved_session.dart';
import '../services/database_service.dart';
import '../widgets/gallery_grid.dart';
import '../services/audio_recording_service.dart';
import '../models/visual_theme.dart';

/// Gallery screen showing saved meditation artwork
class GalleryScreen extends StatefulWidget {
  final AppVisualTheme visualTheme;

  const GalleryScreen({
    super.key,
    this.visualTheme = AppVisualTheme.blueNeon,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<SavedSession> _sessions = [];
  bool _isLoading = true;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    
    try {
      final sessions = await _databaseService.getAllSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load gallery: $e')),
        );
      }
    }
  }

  void _onSessionTap(SavedSession session) {
    if (_isEditMode) {
      // In edit mode, tapping deletes
      _deleteSession(session);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SessionDetailScreen(
            session: session,
            visualTheme: widget.visualTheme,
          ),
        ),
      );
    }
  }

  void _onSessionLongPress(SavedSession session) {
    final isDark = widget.visualTheme == AppVisualTheme.blueNeon;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(widget.visualTheme),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.share, color: isDark ? Colors.white : Colors.black87),
            title: Text('Share', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              _shareSession(session);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: AppTheme.highlight),
            title: const Text('Delete', style: TextStyle(color: AppTheme.highlight)),
            onTap: () {
              Navigator.pop(context);
              _deleteSession(session);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _shareSession(SavedSession session) async {
    final drawings = session.validDrawings;
    if (drawings.isEmpty) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final files = <XFile>[];

      for (int i = 0; i < drawings.length; i++) {
        final file = File('${tempDir.path}/mindart_${session.sessionTime}_$i.png');
        await file.writeAsBytes(drawings[i]);
        files.add(XFile(file.path));
      }

      await Share.shareXFiles(
        files,
        text: 'My artwork from ${session.meditationTitle}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  Future<void> _deleteSession(SavedSession session) async {
    final isDark = widget.visualTheme == AppVisualTheme.blueNeon;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(widget.visualTheme),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Session?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('This will permanently delete this session and all its artwork.', 
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.highlight)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _databaseService.deleteSession(session.sessionTime);
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.visualTheme == AppVisualTheme.blueNeon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Saved sessions',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_sessions.length} ${_sessions.length == 1 ? 'session' : 'sessions'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              if (_sessions.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _isEditMode = !_isEditMode),
                  child: Text(
                    _isEditMode ? 'Done' : 'Edit',
                    style: TextStyle(
                      color: _isEditMode ? AppTheme.highlight : (isDark ? AppTheme.calmBlue : AppTheme.getPrimaryColor(widget.visualTheme)),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: GalleryGrid(
                    sessions: _sessions,
                    onSessionTap: _onSessionTap,
                    onSessionLongPress: _onSessionLongPress,
                    isEditMode: _isEditMode,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Detail screen showing all artwork from a session
class SessionDetailScreen extends StatelessWidget {
  final SavedSession session;
  final AppVisualTheme visualTheme;

  const SessionDetailScreen({
    super.key,
    required this.session,
    this.visualTheme = AppVisualTheme.blueNeon,
  });

  @override
  Widget build(BuildContext context) {
    final drawings = session.validDrawings;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: visualTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.black87),
        title: Text(session.meditationTitle, style: TextStyle(color: visualTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.black87)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareDrawings(context, drawings),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getBackgroundGradient(visualTheme),
        ),
        child: SafeArea(
          child: drawings.isEmpty
              ? const Center(
                  child: Text('No artwork in this session'),
                )
              : PageView.builder(
                  itemCount: drawings.length,
                  itemBuilder: (context, index) {
                    final label = index < session.drawingLabels.length
                        ? session.drawingLabels[index]
                        : null;

                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          if (label != null && label.isNotEmpty) ...[
                            Text(
                              label,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                          ],
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: AppTheme.cardShadow,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(
                                      drawings[index],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                // Audio playback button overlay
                                if (index < session.audioRecordings.length && session.audioRecordings[index] != null)
                                  Positioned(
                                    bottom: 16,
                                    right: 16,
                                    child: FloatingActionButton.small(
                                      backgroundColor: AppTheme.calmBlue.withOpacity(0.8),
                                      onPressed: () => AudioRecordingService().playAudio(session.audioRecordings[index]!),
                                      child: const Icon(Icons.play_arrow, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${index + 1} of ${drawings.length}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _shareDrawings(BuildContext context, List<Uint8List> drawings) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = <XFile>[];

      for (int i = 0; i < drawings.length; i++) {
        final file = File('${tempDir.path}/mindart_${session.sessionTime}_$i.png');
        await file.writeAsBytes(drawings[i]);
        files.add(XFile(file.path));
      }

      await Share.shareXFiles(
        files,
        text: 'My artwork from ${session.meditationTitle}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }
}
