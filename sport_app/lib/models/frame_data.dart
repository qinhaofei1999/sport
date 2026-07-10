import 'pose_landmark.dart';

class FrameData {
  final int frame;
  final double timestamp;
  final bool detected;
  final Map<String, double?> angles;
  final List<PoseLandmark> landmarks;

  const FrameData({
    required this.frame,
    required this.timestamp,
    required this.detected,
    this.angles = const {},
    this.landmarks = const [],
  });

  Map<String, dynamic> toJson() => {
        'frame': frame,
        'timestamp': timestamp,
        'detected': detected,
        'angles': angles.map((k, v) => MapEntry(k, v)),
        'landmarks': landmarks.map((l) => l.toJson()).toList(),
      };

  factory FrameData.fromJson(Map<String, dynamic> json) => FrameData(
        frame: json['frame'] as int,
        timestamp: (json['timestamp'] as num).toDouble(),
        detected: json['detected'] as bool,
        angles: (json['angles'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num?)?.toDouble())),
        landmarks: (json['landmarks'] as List<dynamic>)
            .map((l) => PoseLandmark.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}
