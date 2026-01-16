import 'dart:typed_data';

/// A saved meditation session with drawings
class SavedSession {
  final int? id;
  final int meditationId;
  final String meditationTitle;
  final int sessionTime;
  final List<Uint8List?> drawings;
  final List<String?> drawingLabels;
  final List<Uint8List?> audioRecordings;
  final int? locationX;
  final int? locationY;

  const SavedSession({
    this.id,
    required this.meditationId,
    required this.meditationTitle,
    required this.sessionTime,
    this.drawings = const [],
    this.drawingLabels = const [],
    this.audioRecordings = const [],
    this.locationX,
    this.locationY,
  });

  /// Create from database row
  factory SavedSession.fromMap(Map<String, dynamic> map) {
    final drawings = <Uint8List?>[];
    final labels = <String?>[];
    final audio = <Uint8List?>[];
    
    for (int i = 1; i <= 10; i++) {
      drawings.add(map['drawing$i'] as Uint8List?);
      labels.add(map['drawing${i}_label'] as String?);
      audio.add(map['audio$i'] as Uint8List?);
    }

    return SavedSession(
      id: map['id'] as int?,
      meditationId: map['meditation_id'] as int,
      meditationTitle: map['meditation_title'] as String,
      sessionTime: map['session_time'] as int,
      drawings: drawings,
      drawingLabels: labels,
      audioRecordings: audio,
      locationX: map['location_x'] as int?,
      locationY: map['location_y'] as int?,
    );
  }

  /// Convert to database map for saving
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'meditation_id': meditationId,
      'meditation_title': meditationTitle,
      'session_time': sessionTime,
      'location_x': locationX,
      'location_y': locationY,
    };

    for (int i = 0; i < drawings.length && i < 10; i++) {
      map['drawing${i + 1}'] = drawings[i];
      if (i < drawingLabels.length) {
        map['drawing${i + 1}_label'] = drawingLabels[i];
      }
      if (i < audioRecordings.length) {
        map['audio${i + 1}'] = audioRecordings[i];
      }
    }

    return map;
  }

  /// Get formatted date from session time (Unix timestamp)
  DateTime get sessionDate => DateTime.fromMillisecondsSinceEpoch(sessionTime);

  /// Get list of non-null drawings
  List<Uint8List> get validDrawings => 
    drawings.where((d) => d != null).cast<Uint8List>().toList();

  /// Number of drawings in this session
  int get drawingCount => validDrawings.length;

  /// Copy with updated drawings and audio
  SavedSession copyWithDrawing(int index, Uint8List drawing, String? label, {Uint8List? audio}) {
    final newDrawings = List<Uint8List?>.from(drawings);
    final newLabels = List<String?>.from(drawingLabels);
    final newAudio = List<Uint8List?>.from(audioRecordings);
    
    while (newDrawings.length <= index) {
      newDrawings.add(null);
      newLabels.add(null);
      newAudio.add(null);
    }
    
    newDrawings[index] = drawing;
    if (label != null) newLabels[index] = label;
    if (audio != null) newAudio[index] = audio;
    
    return SavedSession(
      id: id,
      meditationId: meditationId,
      meditationTitle: meditationTitle,
      sessionTime: sessionTime,
      drawings: newDrawings,
      drawingLabels: newLabels,
      audioRecordings: newAudio,
      locationX: locationX,
      locationY: locationY,
    );
  }
}
