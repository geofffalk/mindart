import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/audio_recording_service.dart';

/// Dialog for recording audio voice notes
class AudioRecordDialog extends StatefulWidget {
  final int maxDurationSeconds;
  final Uint8List? initialData;

  const AudioRecordDialog({
    super.key,
    this.maxDurationSeconds = 120, // 2 minutes
    this.initialData,
  });

  @override
  State<AudioRecordDialog> createState() => _AudioRecordDialogState();
}

class _AudioRecordDialogState extends State<AudioRecordDialog> {
  final AudioRecordingService _audioService = AudioRecordingService();
  
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  Uint8List? _recordedData;

  @override
  void initState() {
    super.initState();
    _elapsedSeconds = 0;
    _recordedData = widget.initialData;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.stopPlayback();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_elapsedSeconds < widget.maxDurationSeconds) {
        setState(() {
          _elapsedSeconds++;
        });
      } else {
        _stopRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      await _audioService.startRecording();
      setState(() {
        _isRecording = true;
        _recordedData = null;
        _elapsedSeconds = 0;
      });
      _startTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final data = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
      _recordedData = data;
    });
  }

  void _reset() {
    setState(() {
      _recordedData = null;
      _isRecording = false;
      _elapsedSeconds = 0;
    });
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.primaryDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Record Voice Note', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Describe your drawing or how you feel.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          
          // Timer display
          Text(
            _formatTime(_elapsedSeconds),
            style: TextStyle(
              color: _isRecording ? Colors.red : AppTheme.calmBlue,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Progress bar
          LinearProgressIndicator(
            value: _elapsedSeconds / widget.maxDurationSeconds,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isRecording ? Colors.red : AppTheme.calmBlue
            ),
          ),
          
          const SizedBox(height: 30),
          
          if (_recordedData == null && !_isRecording)
            IconButton(
              iconSize: 80,
              icon: const Icon(Icons.mic, color: Colors.white),
              onPressed: _startRecording,
            )
          else if (_isRecording)
            IconButton(
              iconSize: 80,
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              onPressed: _stopRecording,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                  onPressed: _reset,
                ),
                const SizedBox(width: 20),
                IconButton(
                  iconSize: 60,
                  icon: const Icon(Icons.play_arrow, color: AppTheme.calmBlue),
                  onPressed: () => _audioService.playAudio(_recordedData!),
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        if (_recordedData != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.calmBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(_recordedData),
            child: const Text('Save Note'),
          ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
