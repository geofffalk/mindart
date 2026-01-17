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
import '../widgets/locating_animation.dart';
import '../widgets/opening_animation.dart';
import '../widgets/path_animation.dart';
import '../models/visual_theme.dart';
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
  bool _audioFinished = false;  // Track if audio for segment has finished
  bool _timerFinished = false;  // Track if duration timer has finished
  Timer? _sequenceTimer;        // Timer for sequenceTiming delay
  int _playTransactionId = 0;   // Track current playback "transaction" to prevent race conditions

  // Animation controllers for different segment types
  late AnimationController _pathAnimationController;
  List<Offset>? _currentPathData;
  final List<List<Offset>> _completedPaths = []; // Persists after animation completes
  bool _isHandScanMeditation = false;
  
  // Dynamic path data loaded from segment.graphic configuration
  // Maps path ID (e.g., 'body_outer', 'feet') to path points
  final Map<String, List<Offset>> _loadedPaths = {};
  
  // Multi-path data from JSON files (e.g., 'cushion' -> {'outline': [...], 'detail': [...]})
  // Used when a JSON file contains multiple named path arrays
  final Map<String, Map<String, List<Offset>>> _loadedMultiPaths = {};
  
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
  
  // User-selected location from LOCATING segment (persists for OPENING)
  Offset? _userLocation;
  
  // Drawing persistence for fading segments
  final Map<int, Uint8List> _savedDrawings = {};
  late AnimationController _fadeAnimationController;
  late AppVisualTheme _visualTheme;

  @override
  void initState() {
    super.initState();
    _sessionTime = DateTime.now().millisecondsSinceEpoch;
    
    // Load preferences from settings
    _genderPrefix = SettingsService().getGender();
    _visualTheme = SettingsService().getTheme();
    
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
    
    // HandScanAnimation disabled - all meditations use body CSV paths
    _isHandScanMeditation = false;
    
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
    _sequenceTimer?.cancel();
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
        // Expand body_full to standard outer and inner outlines
        expanded.add('body_outer');
        expanded.add('body_inner');
      } else {
        expanded.add(id);
      }
    }
    return expanded;
  }
  
  Future<Map<String, List<Offset>>?> _loadSinglePath(String pathId) async {
    if (_loadedPaths.containsKey(pathId)) return {pathId: _loadedPaths[pathId]!};
    if (_loadedMultiPaths.containsKey(pathId)) return _loadedMultiPaths[pathId];
    
    try {
      // First try JSON multi-path format (e.g., assets/body_paths/man_meditate.json)
      final jsonPaths = await _meditationService.loadJsonPaths(pathId, _genderPrefix);
      if (jsonPaths.isNotEmpty) {
        // Store the multi-path data
        _loadedMultiPaths[pathId] = jsonPaths;
        debugPrint('📍 Loaded JSON multi-path $pathId with ${jsonPaths.length} sub-paths');
        return jsonPaths;
      }
    } catch (_) {
      // JSON not found or invalid, try CSV
    }
    
    try {
      // Fall back to CSV format (for older assets)
      final pathData = await _meditationService.loadAbsolutePath(pathId, _genderPrefix);
      if (pathData.isNotEmpty) {
        _loadedPaths[pathId] = pathData;
        return {pathId: pathData}; 
      }
    } catch (e) {
      debugPrint('Failed to load path $pathId: $e');
    }
    return null; // Path not found
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
      final loadedData = await _loadSinglePath(id);
      if (loadedData != null && loadedData.length == 1 && loadedData.containsKey(id)) {
        // It was a single path, already stored in _loadedPaths by _loadSinglePath
      } else if (loadedData != null && loadedData.length > 1) {
        // It was a multi-path, stored in _loadedMultiPathData by _loadSinglePath
        // We don't need to do anything here, it's already cached.
      }
    }
    
    // Multi-path expansion: check if any loaded IDs are JSON multi-paths
    // and expand them into individual path references (e.g., man_meditate_path_1)
    final finalStrokeIds = <String>[];
    for (final id in strokeIds) {
      if (_loadedMultiPaths.containsKey(id)) {
        final multiPaths = _loadedMultiPaths[id]!;
        for (final subId in multiPaths.keys) {
          final compositeId = '${id}_$subId';
          _loadedPaths[compositeId] = multiPaths[subId]!;
          finalStrokeIds.add(compositeId);
        }
      } else {
        finalStrokeIds.add(id);
      }
    }
    
    final finalFillIds = <String>[];
    for (final id in fillIds) {
      if (_loadedMultiPaths.containsKey(id)) {
        final multiPaths = _loadedMultiPaths[id]!;
        for (final subId in multiPaths.keys) {
          final compositeId = '${id}_$subId';
          _loadedPaths[compositeId] = multiPaths[subId]!;
          finalFillIds.add(compositeId);
        }
      } else {
        finalFillIds.add(id);
      }
    }
    
    final finalAnimationIds = <String>[];
    for (final id in animationIds) {
      if (_loadedMultiPaths.containsKey(id)) {
        final multiPaths = _loadedMultiPaths[id]!;
        for (final subId in multiPaths.keys) {
          final compositeId = '${id}_$subId';
          _loadedPaths[compositeId] = multiPaths[subId]!;
          finalAnimationIds.add(compositeId);
        }
      } else {
        finalAnimationIds.add(id);
      }
    }
    
    // Update current segment's path configurations
    setState(() {
      // Clear all current paths first to ensure a clean state for the new segment
      _currentStrokePaths = finalStrokeIds;
      _currentFillPaths = finalFillIds;
      _currentAnimationPaths = finalAnimationIds;
      _currentFillBitmapIds = graphic.endFillBitmapIds;
      _allAnimationsComplete = finalAnimationIds.isEmpty; // If no animations, consider complete immediately for bitmaps
      
      // Clear completed paths on segment change
      _completedPaths.clear();
      
      // Set up for first animation path
      _currentAnimationIndex = 0;
      if (finalAnimationIds.isNotEmpty && _loadedPaths.containsKey(finalAnimationIds.first)) {
        _currentPathData = _loadedPaths[finalAnimationIds.first];
      } else {
        _currentPathData = null;
      }
    });
  }

  void _play() async {
    if (_meditation == null) return;
    
    _hasStarted = true;

    final segment = _meditation!.currentSegment;
    
    // Increment transaction ID at start to invalidate any previous listeners/timers
    _playTransactionId++;
    final int currentId = _playTransactionId;

    // For recording segments: reset state, load paths, but don't auto-play audio
    if (segment.segmentType == SegmentType.recording) {
      setState(() {
        _playerState = PlayerState.paused;
        _audioFinished = false;
        _timerFinished = false;
        _completedPaths.clear();
        _allAnimationsComplete = (segment.graphic.animationPathIds.isEmpty);
      });
      if (!_isHandScanMeditation) {
        await _loadPathForSegment(segment);
      }
      return;
    }

    setState(() {
      _playerState = PlayerState.playing;
      _audioFinished = false;
      _timerFinished = false;
      _completedPaths.clear();
      _allAnimationsComplete = (segment.graphic.animationPathIds.isEmpty);
    });
    
    // Load path data for this segment based on its graphic configuration
    if (!_isHandScanMeditation) {
      await _loadPathForSegment(segment);
    }
    
    // Start path animation if this segment has animation paths
    if (segment.graphic.animationPathIds.isNotEmpty) {
      // Respect animationSpeed: calculate duration based on path length
      // If speed is 100 and points is 1000, duration = 10s
      final firstPathId = _currentAnimationPaths.first;
      final firstPathPoints = _loadedPaths[firstPathId]?.length ?? 0;
      
      // Calculate speed-based duration (seconds)
      // Dividing by speed/10 to get reasonable durations for standard CSVs
      double calculatedSeconds = firstPathPoints / (segment.graphic.animationSpeed.clamp(1, 9999) / 10.0);
      calculatedSeconds = calculatedSeconds.clamp(0.5, 60.0); // Keep it sane
      
      _pathAnimationController.duration = Duration(milliseconds: (calculatedSeconds * 1000).toInt());
      
      debugPrint('Starting animation for segment ${segment.id}: Speed ${segment.graphic.animationSpeed}, Points $firstPathPoints, Duration ${calculatedSeconds}s');
      
      // Implement sequenceTiming support
      _sequenceTimer?.cancel();
      if (segment.graphic.sequenceTiming > 0) {
        debugPrint('⏳ sequenceTiming delay: ${segment.graphic.sequenceTiming}ms');
        _sequenceTimer = Timer(Duration(milliseconds: segment.graphic.sequenceTiming), () {
          if (mounted && _playerState == PlayerState.playing) {
            _pathAnimationController.forward(from: 0.0);
          }
        });
      } else {
        _pathAnimationController.forward(from: 0.0);
      }
      
      // Remove any existing listener before adding to prevent duplicates
      _pathAnimationController.removeStatusListener(_onPathAnimationComplete);
      _pathAnimationController.addStatusListener(_onPathAnimationComplete);
      debugPrint('✅ Animation listener ATTACHED.');
    } else {
      // No animation paths - show bitmaps immediately if this segment has any
      if (segment.graphic.endFillBitmapIds.isNotEmpty) {
        setState(() {
          _allAnimationsComplete = true;
        });
      }
    }
    
    // Start fade animation for fading segments
    if (segment.segmentType == SegmentType.fading) {
      _fadeAnimationController.duration = Duration(seconds: segment.duration);
      _fadeAnimationController.reverse(from: 1.0);
    }
    
    // Start min duration timer
    _startProgressTimer();

    // Play audio for current segment
  if (segment.audioLocation.isNotEmpty) {
    // Transaction ID already incremented at start of _play()
    
    debugPrint('🎵 MeditationPlayerScreen: Starting playAsset for ${segment.audioLocation} (ID: $currentId)');
    _audioService.playAsset(segment.audioLocation).then((success) {
      if (!mounted || currentId != _playTransactionId) return;
      
      if (!success) {
        debugPrint('⚠️ Audio failed to load for segment ${segment.id}, proceeding without audio.');
        setState(() {
          _audioFinished = true;
          _checkSegmentCompletion();
        });
      }
    });
    
    _audioService.onComplete(() {
      if (!mounted || currentId != _playTransactionId) return;
      
      debugPrint('🎵 Audio finished for segment ${segment.id} (ID: $currentId)');
      setState(() {
        _audioFinished = true;
        _checkSegmentCompletion();
      });
    });
  } else {
    // No audio, consider audio finished immediately
    setState(() {
      _audioFinished = true;
      _checkSegmentCompletion();
    });
  }
}

  void _checkSegmentCompletion() {
    if (_audioFinished && _timerFinished) {
      debugPrint('✅ Both audio and timer finished. Moving to next segment.');
      _onSegmentComplete();
    } else {
      if (!_audioFinished && _timerFinished) {
        debugPrint('⏳ Timer finished, waiting for audio...');
      } else if (_audioFinished && !_timerFinished) {
        debugPrint('⏳ Audio finished, waiting for timer (${_meditation!.currentSegment.duration}s)...');
      }
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
            _completedPaths.add(List.from(_currentPathData!));
          }
          // Load next path
          _currentPathData = _loadedPaths[nextPathId];
        });
        
        // Start animating the next path
        final nextPathPoints = _currentPathData?.length ?? 0;
        final segment = _meditation!.currentSegment;
        double nextCalculatedSeconds = nextPathPoints / (segment.graphic.animationSpeed.clamp(1, 9999) / 10.0);
        nextCalculatedSeconds = nextCalculatedSeconds.clamp(0.5, 60.0);
        
        _pathAnimationController.duration = Duration(milliseconds: (nextCalculatedSeconds * 1000).toInt());
        debugPrint('Next path duration: ${nextCalculatedSeconds}s (Points: $nextPathPoints)');
        
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
    
    final segment = _meditation!.currentSegment;
    
    // For LOCATING segments, don't auto-advance - wait for user tap
    if (segment.segmentType == SegmentType.locating && _userLocation == null) {
      debugPrint('📍 LOCATING segment - waiting for user tap before advancing');
      return;
    }
    
    // Remove the animation listener to avoid duplicate calls
    _pathAnimationController.removeStatusListener(_onPathAnimationComplete);
    
    // Persist the current animation paths to the completed list
    if (_currentPathData != null && _currentPathData!.isNotEmpty) {
      // Avoid duplicates if already added in _onPathAnimationComplete
      if (_completedPaths.isEmpty || _completedPaths.last != _currentPathData) {
        _completedPaths.add(List.from(_currentPathData!));
      }
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
    _timerFinished = false;
    
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
        _timerFinished = true;
        _checkSegmentCompletion();
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
    // Show different message for relaxation meditations (no drawing)
    final hasDrawing = _savedDrawings.isNotEmpty;
    final message = hasDrawing
        ? 'Well done! Your artwork has been saved to your gallery.'
        : 'Well done! Take this feeling of calm with you.';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(_visualTheme),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Meditation Complete', style: TextStyle(color: AppTheme.getPrimaryColor(_visualTheme))),
        content: Text(message, style: TextStyle(color: _visualTheme == AppVisualTheme.blueNeon ? Colors.white70 : Colors.black87)),
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
      backgroundColor: Colors.transparent, // Let Container handle background
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getBackgroundGradient(_visualTheme),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              _playerState == PlayerState.loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildPlayer(),
              // Close button top right
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: _visualTheme == AppVisualTheme.blueNeon ? Colors.white70 : Colors.black54),
                  onPressed: () => _showExitConfirmation(),
                ),
              ),
            ],
          ),
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
        // Flexible animation area - expands to fill available space
                const SizedBox(height: 5),
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
                color: _visualTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.black87,
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
            color: _visualTheme == AppVisualTheme.blueNeon ? Colors.white60 : Colors.black45,
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
    
    // For RECORDING segments: show segment's bitmaps with paint button on right
    if (segment.segmentType == SegmentType.recording) {
      return _buildRecordingView(segment);
    }
    
    // For LOCATING segments: show pulsing body outline, allow tap to select location
    if (segment.segmentType == SegmentType.locating) {
      return _buildLocatingAnimation(segment);
    }
    
    // For INVESTIGATING segments: show static user location circle
    // (white circle before recording, with user drawing after)
    if (segment.segmentType == SegmentType.investigating) {
      return _buildInvestigatingAnimation(segment);
    }
    
    // For ASKING segments: show slowly pulsing user location circle
    // (white circle before recording, with user drawing after)
    if (segment.segmentType == SegmentType.asking) {
      return _buildAskingAnimation(segment);
    }
    
    // For OPENING segments: show fading user location circle in a slow calming loop
    if (segment.segmentType == SegmentType.opening) {
      return _buildOpeningAnimation(segment);
    }
    
    // For REVIEWING segments: show saved drawings as horizontal carousel
    if (segment.segmentType == SegmentType.reviewing) {
      return _buildReviewingCarousel();
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
    
    // For BREATHING segments: show pulsing circle animation
    if (segment.segmentType == SegmentType.breathing) {
      return _buildBreathingAnimation(segment);
    }
    
    // For APPEARING segments: fade in the path animations
    if (segment.segmentType == SegmentType.appearing) {
      return _buildAppearingAnimation(segment);
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
          boxShadow: [
            BoxShadow(
              color: AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
          gradient: LinearGradient(
            colors: [
              AppTheme.getPrimaryColor(_visualTheme),
              AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          size: 40,
          color: _visualTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.white,
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
          color: enabled 
              ? (_visualTheme == AppVisualTheme.blueNeon ? Colors.white12 : Colors.black.withValues(alpha: 0.05))
              : (_visualTheme == AppVisualTheme.blueNeon ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
        ),
        child: Icon(
          icon,
          size: 28,
          color: enabled 
              ? (_visualTheme == AppVisualTheme.blueNeon ? Colors.white70 : Colors.black54)
              : (_visualTheme == AppVisualTheme.blueNeon ? Colors.white30 : Colors.black26),
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
    _completedPaths.clear();
    _segmentElapsedSeconds = 0;
    
    _meditation!.move(-1);
    setState(() {});
    _completedPaths.clear();
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
        width: 80,
        height: 80,
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
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
  
  /// Builds the recording view showing segment's bitmaps with paint button on right
  Widget _buildRecordingView(MeditationSegment segment) {
    // Calculate canvas size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const textAreaHeight = 200;
    const closeButtonHeight = 50;
    final availableHeight = screenHeight - topPadding - closeButtonHeight - textAreaHeight - bottomPadding;
    final canvasWidth = screenWidth;
    final canvasHeight = availableHeight;
    
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: Stack(
          children: [
            // Show the segment's configured stroke bitmaps
            ..._currentStrokePaths.map((pathId) {
              final pathData = _loadedPaths[pathId];
              if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
              return PathAnimation(
                pathPoints: pathData,
                progress: 1.0,
                strokeColor: AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: _visualTheme == AppVisualTheme.blueNeon ? 0.24 : 0.6),
                strokeWidth: pathId == 'body_outer' ? 2.0 : 1.5,
                glowColor: Colors.transparent,
                useAbsoluteCoords: true,
                size: const Size(580, 756),
                visualTheme: _visualTheme,
              );
            }),
            // Show the segment's configured fill outlines
            ..._currentFillPaths.map((pathId) {
              final pathData = _loadedPaths[pathId];
              if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
              return PathAnimation(
                pathPoints: pathData,
                progress: 1.0,
                strokeColor: AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: _visualTheme == AppVisualTheme.blueNeon ? 0.4 : 0.75),
                strokeWidth: 2.0,
                glowColor: Colors.transparent,
                useAbsoluteCoords: true,
                size: const Size(580, 756),
                visualTheme: _visualTheme,
              );
            }),
            // Show the actual fill regions (bitmaps)
            if (_allAnimationsComplete) 
              ..._currentFillBitmapIds.map((regionId) {
                final pathData = _loadedPaths[regionId];
                if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
                final fillColor = _getFillColorForRegion(regionId);
                return PathAnimation(
                  pathPoints: pathData,
                  progress: 1.0,
                  strokeColor: Colors.transparent,
                  strokeWidth: 0,
                  showFillOnComplete: true,
                  fillColor: fillColor,
                  useAbsoluteCoords: true,
                  size: const Size(580, 756),
                  visualTheme: _visualTheme,
                );
              }),
            // User location circle if selected
            if (_userLocation != null)
              Positioned(
                left: _userLocation!.dx - (_savedDrawings.isNotEmpty ? 30 : 20),
                top: _userLocation!.dy - (_savedDrawings.isNotEmpty ? 30 : 20),
                child: Container(
                  width: _savedDrawings.isNotEmpty ? 60 : 40,
                  height: _savedDrawings.isNotEmpty ? 60 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            // Paint button positioned to the right
            Positioned(
              right: 40,
              top: canvasHeight / 2 - 40,
              child: _buildRecordButton(),
            ),
          ],
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
        traceColor: AppTheme.getPrimaryColor(_visualTheme),
        strokeWidth: 3.0,
      ),
    );
  }

  /// Builds locating animation for LOCATING segments
  /// Shows pulsing body outline, allows user to tap to select a location
  Widget _buildLocatingAnimation(MeditationSegment segment) {
    // Get all body paths from loaded paths - expand IDs since body_full -> body_outer, body_inner
    final List<List<Offset>> bodyPaths = [];
    // Expand the configured startStrokeBitmapIds (e.g., body_full -> body_outer, body_inner)
    final expandedIds = _expandPathIds(segment.graphic.startStrokeBitmapIds);
    for (final pathId in expandedIds) {
      // If it's a multi-path (like 'meditate'), add all sub-paths
      if (_loadedMultiPaths.containsKey(pathId)) {
        final multiPath = _loadedMultiPaths[pathId]!;
        bodyPaths.addAll(multiPath.values);
        debugPrint('📍 LOCATING using multi-path: $pathId (${multiPath.length} sub-paths)');
      } 
      // Fallback to single path
      else if (_loadedPaths[pathId] != null && _loadedPaths[pathId]!.isNotEmpty) {
        bodyPaths.add(_loadedPaths[pathId]!);
        debugPrint('📍 LOCATING using single path: $pathId');
      }
    }
    
    debugPrint('📍 LOCATING animation - ${bodyPaths.length} paths loaded');
    
    // Calculate canvas dimensions - full width and available height
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const textAreaHeight = 200;
    const closeButtonHeight = 50;
    final availableHeight = screenHeight - topPadding - closeButtonHeight - textAreaHeight - bottomPadding;
    
    // Full width and available height
    final canvasWidth = screenWidth;
    final canvasHeight = availableHeight;
    
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: LocatingAnimation(
          bodyPaths: bodyPaths,
          canvasSize: Size(canvasWidth, canvasHeight),
          outlineColor: AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: 0.6),
          circleColor: _visualTheme == AppVisualTheme.blueNeon ? Colors.white : AppTheme.getPrimaryColor(_visualTheme),
          onLocationSelected: (location) {
            setState(() {
              _userLocation = location;
            });
            debugPrint('📍 User location selected: $location');
            // User tapped - now advance to next segment with short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _meditation != null) {
                _skipNext();
              }
            });
          },
        ),
      ),
    );
  }
  
  /// Helper to build the common base layout for segments with user location
  Widget _buildUserLocationSegmentBase({
    required MeditationSegment segment,
    required Widget circleWidget,
  }) {
    // If no user location was selected, show nothing
    if (_userLocation == null) {
      return const SizedBox(height: 120);
    }
    
    // Calculate canvas dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const textAreaHeight = 200;
    const closeButtonHeight = 50;
    final availableHeight = screenHeight - topPadding - closeButtonHeight - textAreaHeight - bottomPadding;
    
    final canvasWidth = screenWidth;
    final canvasHeight = availableHeight;
    
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: Stack(
          children: [
            // Show the segment's configured stroke bitmaps
            ..._currentStrokePaths.map((pathId) {
              final pathData = _loadedPaths[pathId];
              if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
              return PathAnimation(
                pathPoints: pathData,
                progress: 1.0,
                strokeColor: Colors.white24,
                strokeWidth: 2.0,
                glowColor: Colors.transparent,
                useAbsoluteCoords: true,
                size: const Size(580, 756),
              );
            }),
            // Circle at user location
            circleWidget,
          ],
        ),
      ),
    );
  }
  
  /// Builds the circle content - white if no drawing, drawing if available
  Widget _buildUserLocationCircle({double circleRadius = 40.0}) {
    if (_userLocation == null) return const SizedBox.shrink();
    
    final hasDrawing = _savedDrawings.isNotEmpty;
    final drawingData = hasDrawing ? _savedDrawings.values.first : null;
    
    return Positioned(
      left: _userLocation!.dx - circleRadius,
      top: _userLocation!.dy - circleRadius,
      child: Container(
        width: circleRadius * 2,
        height: circleRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _visualTheme == AppVisualTheme.blueNeon ? Colors.white : AppTheme.getSurfaceColor(_visualTheme),
          border: Border.all(
            color: AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_visualTheme == AppVisualTheme.blueNeon ? Colors.white : AppTheme.getPrimaryColor(_visualTheme)).withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: hasDrawing
            ? ClipOval(
                child: Image.memory(drawingData!, fit: BoxFit.cover),
              )
            : null,
      ),
    );
  }
  
  /// Builds INVESTIGATING animation - static user location circle
  Widget _buildInvestigatingAnimation(MeditationSegment segment) {
    return _buildUserLocationSegmentBase(
      segment: segment,
      circleWidget: _buildUserLocationCircle(),
    );
  }
  
  /// Builds ASKING animation - slowly pulsing user location circle
  Widget _buildAskingAnimation(MeditationSegment segment) {
    return _buildUserLocationSegmentBase(
      segment: segment,
      circleWidget: _buildSlowPulsingCircle(),
    );
  }
  
  /// Builds OPENING animation - fading user location circle in slow calming loop
  Widget _buildOpeningAnimation(MeditationSegment segment) {
    return _buildUserLocationSegmentBase(
      segment: segment,
      circleWidget: _buildFadingCircle(),
    );
  }
  
  /// Slowly pulsing circle for ASKING segments
  Widget _buildSlowPulsingCircle({double circleRadius = 40.0}) {
    if (_userLocation == null) return const SizedBox.shrink();
    
    return Positioned(
      left: _userLocation!.dx - circleRadius,
      top: _userLocation!.dy - circleRadius,
      child: _SlowPulsingCircle(
        circleRadius: circleRadius,
        drawingData: _savedDrawings.isNotEmpty ? _savedDrawings.values.first : null,
      ),
    );
  }
  
  /// Fading circle for OPENING segments
  Widget _buildFadingCircle({double circleRadius = 40.0}) {
    if (_userLocation == null) return const SizedBox.shrink();
    
    return Positioned(
      left: _userLocation!.dx - circleRadius,
      top: _userLocation!.dy - circleRadius,
      child: _FadingCircle(
        circleRadius: circleRadius,
        drawingData: _savedDrawings.isNotEmpty ? _savedDrawings.values.first : null,
      ),
    );
  }
  
  /// Builds the reviewing carousel for REVIEWING segments
  /// Shows saved drawings as a horizontally scrollable carousel
  Widget _buildReviewingCarousel() {
    if (_savedDrawings.isEmpty) {
      return Center(
        child: Text(
          'No drawings to review',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 18,
          ),
        ),
      );
    }
    
    // Sort drawings by index
    final sortedEntries = _savedDrawings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    return PageView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Text(
                'Drawing ${entry.key}',
                style: TextStyle(
                  color: _visualTheme == AppVisualTheme.blueNeon ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      entry.value,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Scroll indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  sortedEntries.length,
                  (i) => Container(
                    width: i == index ? 12 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == index 
                          ? (_visualTheme == AppVisualTheme.blueNeon ? Colors.white : Colors.black87)
                          : (_visualTheme == AppVisualTheme.blueNeon ? Colors.white.withValues(alpha: 0.4) : Colors.black26),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Builds breathing animation - pulsing circle for breathing exercises
  Widget _buildBreathingAnimation(MeditationSegment segment) {
    // Calculate canvas size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const textAreaHeight = 200;
    const closeButtonHeight = 50;
    final availableHeight = screenHeight - topPadding - closeButtonHeight - textAreaHeight - bottomPadding;
    
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: screenWidth,
        height: availableHeight,
        child: Center(
          child: _BreathingCircle(visualTheme: _visualTheme),
        ),
      ),
    );
  }
  
  /// Builds appearing animation - fade in the path animations
  Widget _buildAppearingAnimation(MeditationSegment segment) {
    // Calculate canvas size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const textAreaHeight = 200;
    const closeButtonHeight = 50;
    final availableHeight = screenHeight - topPadding - closeButtonHeight - textAreaHeight - bottomPadding;
    final canvasWidth = screenWidth;
    final canvasHeight = availableHeight;
    
    // Use segment duration for fade-in (divide by 3 for faster fade)
    final fadeSeconds = (segment.duration > 0 ? segment.duration : 5) ~/ 3;
    final fadeDuration = Duration(seconds: fadeSeconds > 0 ? fadeSeconds : 2);
    
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: fadeDuration,
          curve: Curves.easeIn,
          builder: (context, opacity, child) {
            return Opacity(
              opacity: opacity,
              child: Stack(
                children: [
                  // Stroke paths with fade
                  ..._currentStrokePaths.map((pathId) {
                    final pathData = _loadedPaths[pathId];
                    if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
                    return PathAnimation(
                      pathPoints: pathData,
                      progress: 1.0,
                      strokeColor: _visualTheme == AppVisualTheme.blueNeon ? Colors.white24 : Colors.black12,
                      strokeWidth: 2.0,
                      glowColor: Colors.transparent,
                      useAbsoluteCoords: true,
                      size: const Size(580, 756),
                      visualTheme: _visualTheme,
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  /// Builds path animation for body scan segments with CSV path data
  Widget _buildPathAnimation() {
    return AnimatedBuilder(
      animation: _pathAnimationController,
      builder: (context, child) {
        // Calculate canvas size with 580:756 aspect ratio (width:height)
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final topPadding = MediaQuery.of(context).padding.top;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        const textAreaHeight = 200; // Text + controls at bottom
        const closeButtonHeight = 50; // X button at top
        final availableHeight = screenHeight - topPadding - closeButtonHeight - textAreaHeight - bottomPadding;
        
        // Full width and available height
        final canvasWidth = screenWidth;
        final canvasHeight = availableHeight;
        
        debugPrint('🎨 MeditationPlayerScreen: _visualTheme = $_visualTheme, BgColor = ${AppTheme.getBackgroundColor(_visualTheme)}, Primary = ${AppTheme.getPrimaryColor(_visualTheme)}');
        
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: Stack(
                children: [
                      // Static stroke paths
                      ..._currentStrokePaths.map((pathId) {
                        final pathData = _loadedPaths[pathId];
                        if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
                        return PathAnimation(
                          pathPoints: pathData,
                          progress: 1.0,
                          strokeColor: AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: _visualTheme == AppVisualTheme.blueNeon ? 0.24 : 0.6),
                          strokeWidth: pathId == 'body_outer' ? 2.0 : 1.5,
                          glowColor: Colors.transparent,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                          animationStyle: _meditation?.currentSegment.graphic.animationStyle ?? 1,
                          visualTheme: _visualTheme,
                        );
                      }),
                      // Static fill paths
                      ..._currentFillPaths.map((pathId) {
                        final pathData = _loadedPaths[pathId];
                        if (pathData == null || pathData.isEmpty) return const SizedBox.shrink();
                        return PathAnimation(
                          pathPoints: pathData,
                          progress: 1.0,
                          strokeColor: AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: _visualTheme == AppVisualTheme.blueNeon ? 0.4 : 0.75),
                          strokeWidth: 2.0,
                          glowColor: Colors.transparent,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                          animationStyle: _meditation?.currentSegment.graphic.animationStyle ?? 1,
                          visualTheme: _visualTheme,
                        );
                      }),
                      // Completed paths persistence
                      ..._completedPaths.map((pathData) {
                        return PathAnimation(
                          pathPoints: pathData,
                          progress: 1.0,
                          strokeColor: AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: 0.7),
                          strokeWidth: 2.5,
                          glowColor: Colors.transparent,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                          animationStyle: _meditation?.currentSegment.graphic.animationStyle ?? 1,
                          visualTheme: _visualTheme,
                        );
                      }),
                      // Animated path
                      if (_currentPathData != null && _currentPathData!.isNotEmpty)
                        PathAnimation(
                          pathPoints: _currentPathData!,
                          progress: _pathAnimationController.value,
                          strokeColor: AppTheme.getPrimaryColor(_visualTheme),
                          strokeWidth: 3.5,
                          glowColor: _visualTheme == AppVisualTheme.blueNeon ? AppTheme.getPrimaryColor(_visualTheme) : null,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                          animationStyle: _meditation?.currentSegment.graphic.animationStyle ?? 1,
                          visualTheme: _visualTheme,
                        ),
                      // Fill regions (code-driven, not bitmaps)
                      if (_allAnimationsComplete) ..._currentFillBitmapIds.map((regionId) {
                        // Load the path data for this region
                        final pathData = _loadedPaths[regionId];
                        if (pathData == null || pathData.isEmpty) {
                          debugPrint('No path data for fill region: $regionId');
                          return const SizedBox.shrink();
                        }
                        // Get fill color for this region (default to primary with alpha)
                        final fillColor = _getFillColorForRegion(regionId);
                        return PathAnimation(
                          pathPoints: pathData,
                          progress: 1.0,
                          strokeColor: Colors.transparent,
                          strokeWidth: 0,
                          showFillOnComplete: true,
                          fillColor: fillColor,
                          useAbsoluteCoords: true,
                          size: const Size(580, 756),
                          visualTheme: _visualTheme,
                        );
                      }),
                      // User location overlay (only if LOCATING has happened)
                      if (_userLocation != null)
                        _buildUserLocationOverlay(canvasWidth, canvasHeight),
                ],
              ),
            ),
          );
        },
      );
  }
  
  /// Builds the user location overlay for FOCUSING segments after LOCATING
  /// Shows circle if no drawing saved, shows drawing at location if drawing exists
  Widget _buildUserLocationOverlay(double canvasWidth, double canvasHeight) {
    if (_userLocation == null) return const SizedBox.shrink();
    
    // Check if any drawing has been saved (after RECORDING)
    final hasDrawing = _savedDrawings.isNotEmpty;
    
    // Circle radius for overlay (half size)
    const circleRadius = 20.0;
    
    if (hasDrawing) {
      // Show user drawing at the circle location (semi-transparent)
      final drawingData = _savedDrawings.values.first;
      return Positioned(
        left: _userLocation!.dx - circleRadius,
        top: _userLocation!.dy - circleRadius,
        child: Opacity(
          opacity: 0.7,
          child: ClipOval(
            child: SizedBox(
              width: circleRadius * 2,
              height: circleRadius * 2,
              child: Image.memory(
                drawingData,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );
    } else {
      // Show circle at user location (semi-transparent)
      return Positioned(
        left: _userLocation!.dx - circleRadius,
        top: _userLocation!.dy - circleRadius,
        child: Container(
          width: circleRadius * 2,
          height: circleRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    }
  }


  /// Returns the fill color for a body region (chakra colors)
  Color _getFillColorForRegion(String regionId) {
    // Chakra color mapping
    const Map<String, Color> chakraColors = {
      'feet': Colors.white,
      'body_full': Colors.white24,
      'base': Color(0xFF8B4513),      // Brown
      'sacral': Color(0xFFFF4500),    // Orange-red
      'solarplexus': Color(0xFFFFA500), // Orange
      'heart': Color(0xFFFFD700),     // Yellow/gold
      'throat': Color(0xFF00CED1),    // Cyan
      'head': Color(0xFF4169E1),      // Royal blue
      'crown': Color(0xFF9932CC),     // Purple
    };
    // Default to a visible grey for light themes if no chakra color is defined
    final isDark = _visualTheme == AppVisualTheme.blueNeon;
    return chakraColors[regionId] ?? 
           (isDark 
             ? AppTheme.getPrimaryColor(_visualTheme).withValues(alpha: 0.6) 
             : Colors.grey.withValues(alpha: 0.4));
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showExitConfirmation() {
    final isDark = _visualTheme == AppVisualTheme.blueNeon;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(_visualTheme),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Exit Meditation?',
          style: TextStyle(color: AppTheme.getPrimaryColor(_visualTheme), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your progress in this session will be lost.',
          style: TextStyle(color: textColor.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Continue',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Exit',
              style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Self-contained breathing circle with its own animation controller
class _BreathingCircle extends StatefulWidget {
  final AppVisualTheme visualTheme;
  const _BreathingCircle({required this.visualTheme});

  @override
  State<_BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<_BreathingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10), // 5s inhale + 5s exhale
      vsync: this,
    )..repeat(); // Loop forever
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Create breathing effect: 0->0.5 = inhale (grow), 0.5->1 = exhale (shrink)
        final progress = _controller.value;
        final breathScale = progress < 0.5
            ? 0.6 + (progress * 1.6)  // 0.6 -> 1.4 (inhale)
            : 1.4 - ((progress - 0.5) * 1.6);  // 1.4 -> 0.6 (exhale)
        
        final primaryColor = widget.visualTheme == AppVisualTheme.blueNeon 
            ? AppTheme.getPrimaryColor(widget.visualTheme)
            : AppTheme.getPrimaryColor(widget.visualTheme); // Use same for now, but ensure it's theme-aware
            
        return Transform.scale(
          scale: breathScale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.getPrimaryColor(widget.visualTheme).withValues(alpha: 0.4),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.getPrimaryColor(widget.visualTheme).withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Slowly pulsing circle for ASKING segments
/// Shows white circle (or drawing if available) with slow scale animation
class _SlowPulsingCircle extends StatefulWidget {
  final double circleRadius;
  final Uint8List? drawingData;
  
  const _SlowPulsingCircle({
    required this.circleRadius,
    this.drawingData,
  });
  
  @override
  State<_SlowPulsingCircle> createState() => _SlowPulsingCircleState();
}

class _SlowPulsingCircleState extends State<_SlowPulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    // Slow pulse: 3 seconds per cycle
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    
    // Scale: gentle pulse from 1.0 to 1.15 and back
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Repeat forever
    _controller.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final hasDrawing = widget.drawingData != null;
    
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: widget.circleRadius * 2,
        height: widget.circleRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: hasDrawing
            ? ClipOval(
                child: Image.memory(widget.drawingData!, fit: BoxFit.cover),
              )
            : null,
      ),
    );
  }
}

/// Fading circle for OPENING segments
/// Shows circle fading in and out in a slow calming loop
class _FadingCircle extends StatefulWidget {
  final double circleRadius;
  final Uint8List? drawingData;
  
  const _FadingCircle({
    required this.circleRadius,
    this.drawingData,
  });
  
  @override
  State<_FadingCircle> createState() => _FadingCircleState();
}

class _FadingCircleState extends State<_FadingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    // Slow fade: 4 seconds per cycle
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    
    // Opacity: fade from 1.0 to 0.3 and back
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Repeat forever
    _controller.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final hasDrawing = widget.drawingData != null;
    
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: widget.circleRadius * 2,
        height: widget.circleRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: hasDrawing
            ? ClipOval(
                child: Image.memory(widget.drawingData!, fit: BoxFit.cover),
              )
            : null,
      ),
    );
  }
}
