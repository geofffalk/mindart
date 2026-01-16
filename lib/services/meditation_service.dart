import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/meditation.dart';

/// Metadata for meditation list display
class MeditationInfo {
  final int id;
  final String title;
  final String description;
  final String assetPath;

  const MeditationInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.assetPath,
  });
}

/// Service for loading and managing meditations
class MeditationService {
  static const List<MeditationInfo> _availableMeditations = [
    MeditationInfo(
      id: 0,
      title: 'Relaxation - Short',
      description: 'A short relaxation meditation',
      assetPath: 'assets/meditations/meditation_0.txt',
    ),
    MeditationInfo(
      id: 1,
      title: 'Relaxation - Long',
      description: 'A longer relaxation meditation',
      assetPath: 'assets/meditations/meditation_1.txt',
    ),
    MeditationInfo(
      id: 2,
      title: 'Body Scan - Short',
      description: 'Quick body scan meditation',
      assetPath: 'assets/meditations/meditation_2.txt',
    ),
    MeditationInfo(
      id: 3,
      title: 'Body Scan - Long',
      description: 'Full body scan meditation',
      assetPath: 'assets/meditations/meditation_3.txt',
    ),
    MeditationInfo(
      id: 4,
      title: 'Transformation',
      description: 'Transformation meditation for emotional release',
      assetPath: 'assets/meditations/meditation_4.txt',
    ),
    MeditationInfo(
      id: 5,
      title: 'Situational Processing',
      description: 'Process difficult situations mindfully',
      assetPath: 'assets/meditations/meditation_5.txt',
    ),
    MeditationInfo(
      id: 6,
      title: 'Pain Management',
      description: 'Meditation for physical discomfort',
      assetPath: 'assets/meditations/meditation_6.txt',
    ),
    MeditationInfo(
      id: 7,
      title: 'Sadness Processing',
      description: 'Gentle meditation for emotional healing',
      assetPath: 'assets/meditations/meditation_7.txt',
    ),
    MeditationInfo(
      id: 8,
      title: 'Ask For Help',
      description: 'Meditation for seeking inner guidance',
      assetPath: 'assets/meditations/meditation_8.txt',
    ),
  ];

  /// Get list of available meditations
  List<MeditationInfo> get availableMeditations => _availableMeditations;

  /// Load a full meditation from assets
  Future<Meditation> loadMeditation(MeditationInfo info) async {
    try {
      final jsonString = await rootBundle.loadString(info.assetPath);
      final jsonData = json.decode(jsonString);
      return Meditation.fromJson(jsonData);
    } on Exception catch (e) {
      print('Error loading meditation ${info.title}: $e');
      rethrow;
    }
  }

  /// Load body path coordinates from CSV asset
  Future<List<Offset>> loadBodyPath(String pathName, String model, Size canvasSize) async {
    try {
      final assetPath = 'assets/body_paths/${model}_$pathName.csv';
      final csvString = await rootBundle.loadString(assetPath);
      final lines = csvString.trim().split('\n');
      
      final coordinates = <Offset>[];
      const maxX = 580.0;
      const maxY = 756.0;
      
      for (final line in lines) {
        final parts = line.split(',');
        if (parts.length >= 2) {
          final x = double.tryParse(parts[0].trim()) ?? 0;
          final y = double.tryParse(parts[1].trim()) ?? 0;
          
          // Scale coordinates to canvas size
          final scaledX = (x / maxX) * canvasSize.width;
          final scaledY = (y / maxY) * canvasSize.height;
          
          coordinates.add(Offset(scaledX, scaledY));
        }
      }
      
      return coordinates;
    } on Exception catch (e) {
      print('Error loading body path $pathName: $e');
      return [];
    }
  }

  /// Load body path as normalized (0-1) coordinates for PathAnimation widget
  /// The path is centered horizontally within the 0-1 space
  Future<List<Offset>> loadNormalizedPath(String pathName, String model) async {
    try {
      final assetPath = 'assets/body_paths/${model}_$pathName.csv';
      final csvString = await rootBundle.loadString(assetPath);
      final lines = csvString.trim().split('\n');
      
      // First pass: collect raw coordinates and find bounds
      final rawCoords = <Offset>[];
      double minX = double.infinity, maxX = double.negativeInfinity;
      double minY = double.infinity, maxY = double.negativeInfinity;
      
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 2) {
          final x = double.tryParse(parts[0].trim()) ?? 0;
          final y = double.tryParse(parts[1].trim()) ?? 0;
          rawCoords.add(Offset(x, y));
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
      
      if (rawCoords.isEmpty) return [];
      
      // Calculate dimensions and centering offset
      final width = maxX - minX;
      final height = maxY - minY;
      
      // Second pass: normalize and center
      final coordinates = <Offset>[];
      for (final coord in rawCoords) {
        // Normalize relative to actual bounds, then center
        final normalizedX = (coord.dx - minX) / width;
        final normalizedY = (coord.dy - minY) / height;
        coordinates.add(Offset(normalizedX, normalizedY));
      }
      
      return coordinates;
    } on Exception catch (e) {
      print('Error loading normalized path $pathName: $e');
      return [];
    }
  }

  /// Load body path with raw absolute coordinates
  /// No scaling or transformation - preserves exact spatial relationships
  Future<List<Offset>> loadAbsolutePath(String pathName, String model) async {
    try {
      final assetPath = 'assets/body_paths/${model}_$pathName.csv';
      debugPrint('🔍 Loading path from: $assetPath');
      final csvString = await rootBundle.loadString(assetPath);
      final lines = csvString.trim().split('\n');
      
      final coordinates = <Offset>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 2) {
          final x = double.tryParse(parts[0].trim()) ?? 0;
          final y = double.tryParse(parts[1].trim()) ?? 0;
          coordinates.add(Offset(x, y));
        }
      }
      
      return coordinates;
    } on Exception catch (e) {
      print('Error loading absolute path $pathName: $e');
      return [];
    }
  }
}

