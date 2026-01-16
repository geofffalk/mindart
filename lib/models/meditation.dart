import 'dart:convert';
import 'package:flutter/services.dart';
import 'meditation_segment.dart';

/// A complete meditation with segments and graphics configuration
class Meditation {
  final int id;
  final String title;
  final String description;
  final String author;
  final List<int> coordinateBounds;
  final String touchRegionElement;
  final List<String> pathOnlyInventory;
  final List<String> fillBitmapInventory;
  final List<String> fillBitmapColors;
  final List<String> strokeBitmapInventory;
  final List<String> strokeBitmapColors;
  final List<MeditationSegment> segments;

  int _cursorPosition = 0;

  Meditation({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.coordinateBounds,
    required this.touchRegionElement,
    required this.pathOnlyInventory,
    required this.fillBitmapInventory,
    required this.fillBitmapColors,
    required this.strokeBitmapInventory,
    required this.strokeBitmapColors,
    required this.segments,
  });

  factory Meditation.fromJson(Map<String, dynamic> json) {
    final segmentsList = (json['segments'] as List<dynamic>?)
            ?.map((s) => MeditationSegment.fromJson(s))
            .toList() ??
        [];

    return Meditation(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Untitled Meditation',
      description: json['description'] ?? '',
      author: json['author'] ?? '',
      coordinateBounds: List<int>.from(json['coordinateBounds'] ?? [580, 756]),
      touchRegionElement: json['touchRegionElement'] ?? '',
      pathOnlyInventory: List<String>.from(json['pathOnlyInventory'] ?? []),
      fillBitmapInventory: List<String>.from(json['fillBitmapInventory'] ?? []),
      fillBitmapColors: List<String>.from(json['fillBitmapColors'] ?? []),
      strokeBitmapInventory: List<String>.from(json['strokeBitmapInventory'] ?? []),
      strokeBitmapColors: List<String>.from(json['strokeBitmapColors'] ?? []),
      segments: segmentsList,
    );
  }

  /// Load a meditation from an asset file
  static Future<Meditation> loadFromAsset(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final jsonData = json.decode(jsonString);
    return Meditation.fromJson(jsonData);
  }

  /// Current cursor position in segments
  int get cursorPosition => _cursorPosition;

  /// Total number of segments
  int get totalSegments => segments.length;

  /// Current segment based on cursor
  MeditationSegment get currentSegment => segments[_cursorPosition];

  /// Move cursor by steps, returns true if successful
  bool move(int steps) {
    final newPos = _cursorPosition + steps;
    if (newPos >= 0 && newPos < segments.length) {
      _cursorPosition = newPos;
      return true;
    }
    return false;
  }

  /// Reset cursor to beginning
  void reset() {
    _cursorPosition = 0;
  }

  /// Get total time remaining from current position
  int get timeRemaining {
    int total = 0;
    for (int i = _cursorPosition; i < segments.length; i++) {
      if (segments[i].segmentType != SegmentType.recording) {
        total += segments[i].duration;
      }
    }
    return total;
  }

  /// Check if at end of meditation
  bool get isComplete => _cursorPosition >= segments.length - 1;
}
