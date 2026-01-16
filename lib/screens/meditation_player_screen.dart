import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../config/theme.dart';
import '../models/meditation.dart';
import '../models/meditation_segment.dart';
import '../services/audio_service.dart';
import '../services/meditation_service.dart';
import '../services/settings_service.dart';
import '../widgets/hand_scan_animation.dart';
import '../widgets/path_animation.dart';
import 'paint_screen.dart';

/// Main meditation player screen
class MeditationPlayerScreen extends StatefulWidget {
  final MeditationInfo meditationInfo;

  const MeditationPlayerScreen({
    super.key,
    required this.meditationInfo,
  });

  @override
  State<MeditationPlayerScreen> createState() => _MeditationPlayerScreenState();
}

enum PlayerState { loading, playing, paused, stopped }

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen>
    with TickerProviderStateMixin {
  final MeditationService _meditationService = MeditationService();
  final AudioService _audioService = AudioService();

  Meditation? _meditation;
  PlayerState _playerState = PlayerState.loading;
  int _sessionTime = 0;
  Timer? _progressTimer;
  StreamSubscription<Duration>? _positionSubscription;
  int _currentDrawingIndex = 0;
  bool _hasStarted = false; // Track if playback has ever started
  int _segmentElapsedSeconds = 0; // Track elapsed time in current segment

  // Animation controllers for different segment types
  late AnimationController _pathAnimationController;
  List<Offset>? _currentPathData;
  List<Offset>? _completedPathData; // Persists after animation completes
  bool _isHandScanMeditation = false;
  
  // Dynamic path data loaded from segment.graphic configuration
  // Maps path ID (e.g., 'body_outer', 'feet') to path points
  final Map<String, List<Offset>> _loadedPaths = {};
  
  // Current segment's configured paths
  List<String> _currentStrokePaths = [];  // Stroke outlines to show
  List<String> _currentFillPaths = [];    // Filled regions to show
  List<String> _currentAnimationPaths = []; // Paths being animated
  int _currentAnimationIndex = 0;       // Index of current animation path
  
  // Fill bitmap IDs to display (from endFillBitmapIds after animation)
  List<String> _currentFillBitmapIds = [];
  bool _allAnimationsComplete = false; // Track if all path animations finished
  
  // Gender prefix for loading gender-specific assets (loaded from settings)
  late String _genderPrefix;
  
  // Drawing persistence for fading segments
  final Map<int, Uint8List> _savedDrawings = {};
  late AnimationController _fadeAnimationController;

  @override
  void initState() {
    super.initState();
    _sessionTime = DateTime.now().millisecondsSinceEpoch;
    
    // Load gender preference from settings
    _genderPrefix = SettingsService().getGender();
    
    // Path animation controller - duration set when segment starts
    _pathAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    
    // Fade animation controller for fading segments - starts at 1.0 (fully visible)
    _fadeAnimationController = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(seconds: 10),
    );
    
    // Check if this is a hand scan meditation (ID 0 or 1)
    _isHandScanMeditation = widget.meditationInfo.id == 0 || widget.meditationInfo.id == 1;
    
    _loadMeditation();
    
    // Listen to audio position to update timer during playback
    _positionSubscription = _audioService.positionStream.listen((position) {
      if (mounted && _playerState == PlayerState.playing) {
        setState(() {
          _segmentElapsedSeconds = position.inSeconds;
        });
      }
    });
  }

  Future<void> _loadMeditation() async {
    try {
      final meditation = await _meditationService.loadMeditation(widget.meditationInfo);
      setState(() {
        _meditation = meditation;
        _playerState = PlayerState.paused;
      });
      // Autoplay meditation
      _play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load meditation: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _positionSubscription?.cancel();
    _audioService.dispose();
    _pathAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  /// Expands special path IDs like "body_full" into actual path IDs
  List<String> _expandPathIds(List<String> pathIds) {
    final expanded = <String>[];
    for (final id in pathIds) {
      if (id == 'body_full') {
        expanded.add('body_outer');
        expanded.add('body_inner');
      } else {
        expanded.add(id);
      }
    }
    return expanded;
  }
  
  /// Loads a single path by ID, caching results in _loadedPaths
  Future<void> _loadSinglePath(String pathId) async {
    if (_loadedPaths.containsKey(pathId)) return; // Already loaded
    
    try {
      // TODO: Use user's gender preference instead of hardcoded 'woman'
      // Use absolute coordinates (not normalized)
      final pathData = await _meditationService.loadAbsolutePath(pathId, 'woman');
      if (pathData.isNotEmpty) {
        _loadedPaths[pathId] = pathData;
      }
    } catch (e) {
      debugPrint('Failed to load path $pathId: $e');
    }
  }
  
  /// Loads all paths needed for a segment based on its graphic configuration
  Future<void> _loadPathForSegment(MeditationSegment segment) async {
    final graphic = segment.graphic;
    
    // Expand and collect all needed path IDs
    final strokeIds = _expandPathIds(graphic.startStrokeBitmapIds);
    final fillIds = _expandPathIds(graphic.startFillBitmapIds);
    final animationIds = _expandPathIds(graphic.animationPathIds);
    
    // Load all unique paths
    final allIds = {...strokeIds, ...fillIds, ...animationIds};
    for (final id in allIds) {
      await _loadSinglePath(id);
    }
    
    // Update current segment's path configurations
    setState(() {
      _currentStrokePaths = strokeIds;
      _currentFillPaths = fillIds;
      _currentAnimationPaths = animationIds;
      _currentFillBitmapIds = graphic.endFillBitmapIds;
      _allAnimationsComplete = false; // Reset for new segment
      
      debugPrint('📍 Segment ${segment.id} loaded:');
      debugPrint('  Stroke paths: $strokeIds');
      debugPrint('  Fill paths: $fillIds');
      debugPrint('  Animation paths: $animationIds');
      debugPrint('  END FILL BITMAP IDs: ${graphic.endFillBitmapIds}');
      debugPrint('  _currentFillBitmapIds set to: $_currentFillBitmapIds');
      debugPrint('  _allAnimationsComplete: $_allAnimationsComplete');
      
      // Clear completed path if it's not in the new segment's config
      // This prevents showing animations from previous segments
      if (_completedPathData != null) {
        // Only keep _completedPathData if its corresponding path ID is still relevant
        // Since we don't track the old path ID, just clear it on segment change
        _completedPathData = null;
      }
      
      // Set up for first animation path
      _currentAnimationIndex = 0;
      if (animationIds.isNotEmpty && _loadedPaths.containsKey(animationIds.first)) {
        _currentPathData = _loadedPaths[animationIds.first];
      } else {
        _currentPathData = null;
      }
    });
  }

  void _play() async {
    if (_meditation == null) return;
    
    _hasStarted = true;

    final segment = _meditation!.currentSegment;
    
    // For recording segments, don't auto-play audio - wait for user to tap record button
    // This matches the original Android behavior where the RecordButton is displayed
    if (segment.segmentType == SegmentType.recording) {
      setState(() => _playerState = PlayerState.paused);
      return;
    }

    setState(() => _playerState = PlayerState.playing);
    
    // Load path data for this segment based on its graphic configuration
    // This applies to ALL segment types - reading, appearing, focusing, fading, recording
    if (!_isHandScanMeditation) {
      await _loadPathForSegment(segment);
    }
    
    // Start path animation if this segment has animation paths
    if (segment.graphic.animationPathIds.isNotEmpty) {
      // Split duration among all animation paths for sequential playback
      final pathCount = _currentAnimationPaths.length;
      final durationPerPath = segment.duration ~/ pathCount.clamp(1, 999);
      _pathAnimationController.duration = Duration(seconds: durationPerPath);
      
      debugPrint('Starting animation for segment ${segment.id}: $pathCount paths, ${durationPerPath}s each');
      debugPrint('Animation paths: $_currentAnimationPaths');
      debugPrint('Fill bitmaps: ${segment.graphic.endFillBitmapIds}');
      
      _pathAnimationController.forward(from: 0.0);
      
      // Remove any existing listener before adding to prevent duplicates
      _pathAnimationController.removeStatusListener(_onPathAnimationComplete);
      // Listen for animation completion to sequence through multiple paths
      _pathAnimationController.addStatusListener(_onPathAnimationComplete);
      debugPrint('✅ Animation listener ATTACHED. Duration: ${_pathAnimationController.duration}');
    } else {
      // No animation paths - show bitmaps immediately if this segment has any
      if (segment.graphic.endFillBitmapIds.isNotEmpty) {
        debugPrint('No animation paths - showing bitmaps immediately: ${segment.graphic.endFillBitmapIds}');
        setState(() {
          _allAnimationsComplete = true;
        });
      }
    }
    
    // Start fade animation for fading segments
    if (segment.segmentType == SegmentType.fading) {
      _fadeAnimationController.duration = Duration(seconds: segment.duration);
      _fadeAnimationController.reverse(from: 1.0); // Fade from visible to invisible
    }
    
    // Play audio for current segment
    if (segment.audioLocation.isNotEmpty) {
      _audioService.playAsset(segment.audioLocation);
      _audioService.onComplete(_onSegmentComplete);
    } else {
      // No audio, use timer based on duration
      _startProgressTimer();
    }
  }

  
  void _onPathAnimationComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      debugPrint('Animation completed! Index: $_currentAnimationIndex/${_currentAnimationPaths.length - 1}');
      
      // Animation path completed, check if there are more paths to animate
      if (_currentAnimationIndex + 1 < _currentAnimationPaths.length) {
        // Move to next animation path
        _currentAnimationIndex++;
        final nextPathId = _currentAnimationPaths[_currentAnimationIndex];
        
        debugPrint('Advancing to next path: $nextPathId');
        
        setState(() {
          // Persist current completed path
          if (_currentPathData != null) {
            _completedPathData = _currentPathData;
          }
          // Load next path
          _currentPathData = _loadedPaths[nextPathId];
        });
        
        // Start animating the next path
        _pathAnimationController.forward(from: 0.0);
      } else {
        // No more paths to animate - all animations complete
        // IMPORTANT: Remove listener to prevent looping
        _pathAnimationController.removeStatusListener(_onPathAnimationComplete);
        debugPrint('\n🎉 ALL ANIMATIONS COMPLETE!');
        debugPrint('  Setting _allAnimationsComplete = true');
        debugPrint('  _currentFillBitmapIds = $_currentFillBitmapIds');
        debugPrint('  Gender prefix = $_genderPrefix');
        setState(() {
          _allAnimationsComplete = true;
        });
        debugPrint('  State updated. Bitmaps should now render.');
      }
      // If no more paths, the segment completion will be handled by audio or timer
    }
  }

  void _onSegmentComplete() {
    if (!mounted || _meditation == null) return;
    
    // Remove the animation listener to avoid duplicate calls
    _pathAnimationController.removeStatusListener(_onPathAnimationComplete);
    
    // Persist the completed animation path for the next segment
    if (_currentPathData != null && _currentPathData!.isNotEmpty) {
      _completedPathData = _currentPathData;
    }
    
    // Reset animation and elapsed time for next segment
    _pathAnimationController.reset();
    _currentPathData = null;
    _currentAnimationIndex = 0;
    _segmentElapsedSeconds = 0;
    
    if (_meditation!.move(1)) {
      // Move to next segment
      _play();
    } else {
      // Meditation complete
      setState(() => _playerState = PlayerState.stopped);
      _showCompletionDialog();
    }
  }

  void _startProgressTimer() {
    final duration = _meditation!.currentSegment.duration;
    _progressTimer?.cancel();
    _segmentElapsedSeconds = 0;
    
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _segmentElapsedSeconds++;
      });
      if (_segmentElapsedSeconds >= duration) {
        timer.cancel();
        _onSegmentComplete();
      }
    });
  }

  void _pause() {
    _progressTimer?.cancel();
    _audioService.pause();
    _pathAnimationController.stop();
    setState(() => _playerState = PlayerState.paused);
  }

  void _resume() {
    _audioService.resume();
    final segment = _meditation?.currentSegment;
    if (segment?.segmentType == SegmentType.focusing) {
      // Re-attach listener for sequential animations
      _pathAnimationController.addStatusListener(_onPathAnimationComplete);
      _pathAnimationController.forward();
    }
    setState(() => _playerState = PlayerState.playing);
  }

  void _launchPaintScreen() async {
    final segment = _meditation!.currentSegment;
    _currentDrawingIndex = segment.drawingIndex;

    // PaintScreen returns a record (success, imageData)
    final result = await Navigator.of(context).push<(bool, Uint8List?)>(
      MaterialPageRoute(
        builder: (context) => PaintScreen(
          meditationId: widget.meditationInfo.id,
          meditationTitle: widget.meditationInfo.title,
          sessionTime: _sessionTime,
          drawingIndex: _currentDrawingIndex,
          drawingName: segment.drawingName,
        ),
      ),
    );

    if (result != null && result.$1 && mounted) {
      // Store the drawing image for fading display
      if (result.$2 != null) {
        _savedDrawings[_currentDrawingIndex] = result.$2!;
      }
      
      // Drawing saved, continue to next segment
      if (_meditation!.move(1)) {
        _play();
      } else {
        setState(() => _playerState = PlayerState.stopped);
        _showCompletionDialog();
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Meditation Complete'),
        content: const Text(
          'Well done! Your artwork has been saved to your gallery.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _playerState == PlayerState.loading
              ? const Center(child: CircularProgressIndicator())
              : _buildPlayer(),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final segment = _meditation!.currentSegment;
    // Calculate time remaining: total remaining minus elapsed in current segment
    final segmentTimeRemaining = segment.duration - _segmentElapsedSeconds;
    final timeRemaining = _meditation!.timeRemaining - _segmentElapsedSeconds;

    return Column(
      children: [
        const SizedBox(height: 16),

        // Flexible animation area - expands to fill available space
        Expanded(
          flex: 3,
          child: Center(
            child: _buildAnimationArea(segment),
          ),
        ),

        const SizedBox(height: 16),

        // Fixed height text area - 5 lines max, prevents animation area from moving
        SizedBox(
          height: 100, // Fixed height for up to 5 lines of text
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              segment.description,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Time remaining
        Text(
          _formatTime(timeRemaining),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white60,
          ),
        ),

        const SizedBox(height: 12),

        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LinearProgressIndicator(
            value: _meditation!.cursorPosition / _meditation!.totalSegments,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(AppTheme.calmBlue),
            borderRadius: BorderRadius.circular(4),
          ),
        ),

        const SizedBox(height: 8),

        // Segment counter
        Text(
          'Step ${_meditation!.cursorPosition + 1} of ${_meditation!.totalSegments}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white54,
          ),
        ),

        const SizedBox(height: 16),

        // Navigation and play/pause controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Skip back button
            _buildNavButton(
              icon: Icons.skip_previous,
              onTap: _skipPrevious,
              enabled: _meditation!.cursorPosition > 0,
            ),
            const SizedBox(width: 32),
            // Play/pause button
            _buildPlayButton(),
            const SizedBox(width: 32),
            // Skip forward button
            _buildNavButton(
              icon: Icons.skip_next,
              onTap: _skipNext,
              enabled: _meditation!.cursorPosition < _meditation!.totalSegments - 1,
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAnimationArea(MeditationSegment segment) {
    // For meditation 0 & 1 focusing segments: show hand scan animation
    if (_isHandScanMeditation && segment.segmentType == SegmentType.focusing) {
      return _buildHandScanAnimation();
    }
    
    // For RECORDING segments: show a record button (matching original Android)
    if (segment.segmentType == SegmentType.recording) {
      return _buildRecordButton();
    }
    
    // For FADING segments: display the saved drawing with a fade-out animation
    if (segment.segmentType == SegmentType.fading) {
      final drawingData = _savedDrawings[segment.drawingIndex];
      if (drawingData != null) {
        return FadeTransition(
          opacity: _fadeAnimationController,
          child: Image.memory(
            drawingData,
            fit: BoxFit.contain,
          ),
        );
      }
    }
    
    // For any segment with graphic configurations (stroke, fill, or animation paths):
    // show the path animation - this includes reading, appearing, focusing, etc.
    final hasGraphicConfig = segment.graphic.startStrokeBitmapIds.isNotEmpty ||
        segment.graphic.startFillBitmapIds.isNotEmpty ||
        segment.graphic.animationPathIds.isNotEmpty;
    
    if (hasGraphicConfig && !_isHandScanMeditation) {
      return _buildPathAnimation();
    }
    
    // For other segments with no graphic config: just show empty space
    return const SizedBox(height: 120);
  }

  Widget _buildPlayButton() {
    final isPlaying = _playerState == PlayerState.playing;

    return GestureDetector(
      onTap: isPlaying ? _pause : (
        (_playerState == PlayerState.paused && _hasStarted) ? _resume : _play
      ),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.calmBlue,
          boxShadow: [
            BoxShadow(
              color: AppTheme.calmBlue.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Builds a navigation button (skip forward/back)
  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white12 : Colors.white.withValues(alpha: 0.05),
        ),
        child: Icon(
          icon,
          size: 28,
          color: enabled ? Colors.white70 : Colors.white30,
        ),
      ),
    );
  }

  /// Skip to previous segment
  void _skipPrevious() {
    if (_meditation == null || _meditation!.cursorPosition <= 0) return;
    
    _audioService.stop();
    _progressTimer?.cancel();
    _pathAnimationController.reset();
    _currentPathData = null;
    _segmentElapsedSeconds = 0;
    
    _meditation!.move(-1);
    setState(() {});
    _play();
  }

  /// Skip to next segment
  void _skipNext() {
    if (_meditation == null) return;
    
    if (_meditation!.cursorPosition >= _meditation!.totalSegments - 1) {
      // Last segment - complete meditation
      _onSegmentComplete();
      return;
    }
    
    _audioService.stop();
    _progressTimer?.cancel();
    _pathAnimationController.reset();
    _currentPathData = null;
    _segmentElapsedSeconds = 0;
    
    _meditation!.move(1);
    setState(() {});
    _play();
  }

  /// Builds a record button for RECORDING segments (matching original Android RecordButton)
  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _launchPaintScreen,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accent,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Icon(
          Icons.brush,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Builds the hand scan animation widget for meditation 0 & 1 focusing segments
  Widget _buildHandScanAnimation() {
    // Get current segment duration for the animation
    final currentSegment = _meditation?.currentSegment;
    final durationSeconds = currentSegment?.duration ?? 8;
    final duration = Duration(seconds: durationSeconds);
    
    return SizedBox(
      width: 260,
      height: 280,
      child: HandScanAnimation(
        duration: duration,
        traceColor: AppTheme.primary,
        strokeWidth: 3.0,
      ),
    );
  }

  /// Builds path animation for body scan segments with CSV path data
  Widget _buildPathAnimation() {
    return AnimatedBuilder(
      animation: _pathAnimationController,
      builder: (context, child) {
        // Calculate available height and position animation above text
        final screenHeight = MediaQuery.of(context).size.height;
        final descriptionHeight = 120; // Approximate height of description area
        final paddingBottom = MediaQuery.of(context).padding.bottom;
        final availableHeight = screenHeight - descriptionHeight - paddingBottom - 100;
        final scaledAnimationHeight = 760 * 0.45; // 342px
        final verticalOffset = -(availableHeight - scaledAnimationHeight) / 2 - 10;
        
        return Align(
          alignment: Alignment.centerRight,
          child: Transform.translate(
            offset: Offset(0, verticalOffset),
            child: Transform.scale(
              scale: 0.45,
              child: SizedBox(
                width: 580,
                height: 756,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 2), // DEBUG: Canvas bounds
                  ),
                  child: Stack(
                    children: [
                      // Static stroke paths
                      ..._currentStrokePaths.map((pathId) {
                        final pathData = _loadedPaths[pathId];
                        if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
                        return PathAnimation(
                          pathPoints: pathData,
                          progress: 1.0,
                          strokeColor: Colors.white24,
                          strokeWidth: pathId == 'body_outer' ? 2.0 : 1.5,
                          glowColor: Colors.transparent,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                        );
                      }),
                      // Static fill paths
                      ..._currentFillPaths.map((pathId) {
                        final pathData = _loadedPaths[pathId];
                        if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
                        return PathAnimation(
                          pathPoints: pathData,
                          progress: 1.0,
                          strokeColor: AppTheme.primary.withValues(alpha: 0.5),
                          strokeWidth: 2.0,
                          glowColor: Colors.transparent,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                        );
                      }),
                      // Completed path
                      if (_completedPathData != null && _completedPathData!.isNotEmpty)
                        PathAnimation(
                          pathPoints: _completedPathData!,
                          progress: 1.0,
                          strokeColor: AppTheme.primary.withValues(alpha: 0.7),
                          strokeWidth: 2.5,
                          glowColor: Colors.transparent,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                        ),
                      // Animated path
                      if (_currentPathData != null && _currentPathData!.isNotEmpty)
                        PathAnimation(
                          pathPoints: _currentPathData!,
                          progress: _pathAnimationController.value,
                          strokeColor: AppTheme.primary,
                          strokeWidth: 3.0,
                          glowColor: AppTheme.primaryLight,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                        ),
                      // Fill bitmaps
                      if (_allAnimationsComplete) ..._currentFillBitmapIds.map((bitmapId) {
                        final assetPath = 'assets/images/body/${_genderPrefix}_$bitmapId.png';
                        return Container(
                          width: 580,
                          height: 756,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red, width: 2), // DEBUG
                          ),
                          child: Image.asset(
                            assetPath,
                            width: 580,
                            height: 756,
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('ERROR loading $assetPath: $error');
                              return const SizedBox.shrink();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }



  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Meditation?'),
        content: const Text(
          'Your progress in this session will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
