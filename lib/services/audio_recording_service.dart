import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// Service for recording and playing back audio voice notes
class AudioRecordingService {
  static final AudioRecordingService _instance = AudioRecordingService._internal();
  factory AudioRecordingService() => _instance;
  AudioRecordingService._internal();

  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  /// Recording temp path
  String? _tempPath;

  /// Initialize the recorder and player
  Future<void> init() async {
    if (_isRecorderInitialized && _isPlayerInitialized) return;

    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await _recorder!.openRecorder();
    await _player!.openPlayer();

    _isRecorderInitialized = true;
    _isPlayerInitialized = true;
    
    final tempDir = await getTemporaryDirectory();
    _tempPath = '${tempDir.path}/temp_recording.aac';
  }

  /// Check and request microphone permissions
  Future<bool> checkPermissions() async {
    var status = await Permission.microphone.status;
    if (status != PermissionStatus.granted) {
      status = await Permission.microphone.request();
    }
    return status == PermissionStatus.granted;
  }

  /// Start recording audio to a temporary file
  Future<void> startRecording() async {
    await init();
    if (!await checkPermissions()) {
      throw Exception('Microphone permission not granted');
    }
    
    await _recorder!.startRecorder(
      toFile: _tempPath,
      codec: Codec.aacADTS,
    );
  }

  /// Stop recording and return the audio data as Uint8List
  Future<Uint8List?> stopRecording() async {
    if (_recorder == null || !_recorder!.isRecording) return null;
    
    await _recorder!.stopRecorder();
    
    final file = File(_tempPath!);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      // Clean up temp file
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Error deleting temp recording file: $e');
      }
      return bytes;
    }
    return null;
  }

  /// Play audio from binary data
  Future<void> playAudio(Uint8List data) async {
    await init();
    if (_player!.isPlaying) {
      await _player!.stopPlayer();
    }
    
    await _player!.startPlayer(
      fromDataBuffer: data,
      codec: Codec.aacADTS,
      whenFinished: () {
        debugPrint('Playback finished');
      },
    );
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    if (_player != null && _player!.isPlaying) {
      await _player!.stopPlayer();
    }
  }

  /// Check if currently recording
  bool get isRecording => _recorder?.isRecording ?? false;

  /// Check if currently playing
  bool get isPlaying => _player?.isPlaying ?? false;

  /// Dispose services
  void dispose() {
    _recorder?.closeRecorder();
    _player?.closePlayer();
    _recorder = null;
    _player = null;
    _isRecorderInitialized = false;
    _isPlayerInitialized = false;
  }
}
