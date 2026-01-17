import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Service for audio playback during meditation sessions
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _completionSubscription;
  
  /// Whether audio is currently playing
  bool get isPlaying => _player.playing;
  
  /// Current position in seconds
  Duration get position => _player.position;
  
  /// Current duration in seconds
  Duration? get duration => _player.duration;
  
  /// Stream of playback state
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  /// Stream of position updates
  Stream<Duration> get positionStream => _player.positionStream;

  /// Play an audio asset by name (without extension)
  /// Returns true if play started successfully, false otherwise.
  Future<bool> playAsset(String audioName) async {
    try {
      final assetPath = 'assets/audio/$audioName.mp3';
      debugPrint('🎵 AudioService: Loading $assetPath');
      
      // Ensure volume is set to maximum on every play to avoid silence
      await _player.setVolume(1.0);
      
      await _player.setAsset(assetPath);
      
      // Log player status before playing
      debugPrint('🎵 AudioService: Player state before play: ${_player.processingState}');
      
      // Don't await play() to allow UI to remain responsive, but start it
      _player.play();
      
      debugPrint('🎵 AudioService: Play command sent for $audioName');
      return true;
    } on Exception catch (e) {
      if (e.toString().contains('abort') || e.toString().contains('interrupted')) {
        debugPrint('🎵 AudioService: Loading interrupted for $audioName (skipping/navigation)');
      } else {
        debugPrint('🎵 AudioService: Error playing audio $audioName: $e');
      }
      return false;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await _player.play();
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  /// Listen for playback completion
  void onComplete(void Function() callback) {
    // Cancel any existing subscription to prevent listener accumulation
    _completionSubscription?.cancel();
    _completionSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        callback();
      }
    });
  }

  /// Dispose of the player
  void dispose() {
    _completionSubscription?.cancel();
    _player.dispose();
  }
}
