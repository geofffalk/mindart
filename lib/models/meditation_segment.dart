/// Types of meditation segments
enum SegmentType {
  focusing,
  recording,
  reviewing,
  locating,
  scanning,
  opening,
  fading,
  contracting,
  relaxing,
  appearing,
  cushion,
  breathing,
  reading;

  static SegmentType? fromString(String name) {
    for (final type in values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

/// Graphics configuration for a meditation segment
class SegmentGraphic {
  final List<String> startStrokeBitmapIds;
  final List<String> startFillBitmapIds;
  final int sequenceTiming;
  final List<String> animationPathIds;
  final int animationStyle;
  final int animationSpeed;
  final List<String> endFillBitmapIds;
  final List<String> endStrokeBitmapIds;

  const SegmentGraphic({
    this.startStrokeBitmapIds = const [],
    this.startFillBitmapIds = const [],
    this.sequenceTiming = 0,
    this.animationPathIds = const [],
    this.animationStyle = 0,
    this.animationSpeed = 100,
    this.endFillBitmapIds = const [],
    this.endStrokeBitmapIds = const [],
  });

  factory SegmentGraphic.fromJson(Map<String, dynamic> json) {
    return SegmentGraphic(
      startStrokeBitmapIds: List<String>.from(json['startStrokeBitmapIds'] ?? []),
      startFillBitmapIds: List<String>.from(json['startFillBitmapIds'] ?? []),
      sequenceTiming: json['sequenceTiming'] ?? 0,
      animationPathIds: List<String>.from(json['animationPathIds'] ?? []),
      animationStyle: json['animationStyle'] ?? 0,
      animationSpeed: json['animationSpeed'] ?? 100,
      endFillBitmapIds: List<String>.from(json['endFillBitmapIds'] ?? []),
      endStrokeBitmapIds: List<String>.from(json['endStrokeBitmapIds'] ?? []),
    );
  }
}

/// A single segment within a meditation
class MeditationSegment {
  final int id;
  final String title;
  final String description;
  final SegmentType segmentType;
  final int drawingIndex;
  final String drawingName;
  final String audioLocation;
  final int duration;
  final SegmentGraphic graphic;

  const MeditationSegment({
    required this.id,
    required this.title,
    required this.description,
    required this.segmentType,
    required this.drawingIndex,
    required this.drawingName,
    required this.audioLocation,
    required this.duration,
    required this.graphic,
  });

  factory MeditationSegment.fromJson(Map<String, dynamic> json) {
    return MeditationSegment(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      segmentType: SegmentType.fromString(json['segmentName'] ?? '') ?? SegmentType.reading,
      drawingIndex: json['drawingIndex'] ?? 0,
      drawingName: json['drawingName'] ?? '',
      audioLocation: json['audioLocation'] ?? '',
      duration: json['duration'] ?? 0,
      graphic: SegmentGraphic.fromJson(json['graphic'] ?? {}),
    );
  }

  /// Whether this segment requires user to draw
  bool get isRecordingSegment => segmentType == SegmentType.recording;
}
