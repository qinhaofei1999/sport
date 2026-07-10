import 'frame_data.dart';
import 'gait_event.dart';
import 'gait_cycle.dart';

class VideoMeta {
  final String filename;
  final double fps;
  final int totalFrames;
  final double durationSec;
  final int width;
  final int height;

  const VideoMeta({
    required this.filename,
    required this.fps,
    required this.totalFrames,
    required this.durationSec,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'fps': fps,
        'total_frames': totalFrames,
        'duration_sec': durationSec,
        'width': width,
        'height': height,
      };

  factory VideoMeta.fromJson(Map<String, dynamic> json) => VideoMeta(
        filename: json['filename'] as String,
        fps: (json['fps'] as num).toDouble(),
        totalFrames: json['total_frames'] as int,
        durationSec: (json['duration_sec'] as num).toDouble(),
        width: json['width'] as int,
        height: json['height'] as int,
      );
}

class Stats {
  final int framesProcessed;
  final int framesDetected;
  final double detectionRate;
  final int gaitEvents;
  final double cadenceSpm;

  const Stats({
    required this.framesProcessed,
    required this.framesDetected,
    required this.detectionRate,
    required this.gaitEvents,
    required this.cadenceSpm,
  });

  Map<String, dynamic> toJson() => {
        'frames_processed': framesProcessed,
        'frames_detected': framesDetected,
        'detection_rate': detectionRate,
        'gait_events': gaitEvents,
        'cadence_spm': cadenceSpm,
      };

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
        framesProcessed: json['frames_processed'] as int,
        framesDetected: json['frames_detected'] as int,
        detectionRate: (json['detection_rate'] as num).toDouble(),
        gaitEvents: json['gait_events'] as int,
        cadenceSpm: (json['cadence_spm'] as num).toDouble(),
      );
}

class GaitSummary {
  final int totalSteps;
  final double cadenceSpm;
  final double durationSec;
  final double? avgHipAngleLeft;
  final double? avgHipAngleRight;
  final double? avgKneeAngleLeft;
  final double? avgKneeAngleRight;
  final double? avgAnkleAngleLeft;
  final double? avgAnkleAngleRight;

  const GaitSummary({
    required this.totalSteps,
    required this.cadenceSpm,
    required this.durationSec,
    this.avgHipAngleLeft,
    this.avgHipAngleRight,
    this.avgKneeAngleLeft,
    this.avgKneeAngleRight,
    this.avgAnkleAngleLeft,
    this.avgAnkleAngleRight,
  });

  Map<String, dynamic> toJson() => {
        'total_steps': totalSteps,
        'cadence_spm': cadenceSpm,
        'duration_sec': durationSec,
        'avg_hip_angle_left': avgHipAngleLeft,
        'avg_hip_angle_right': avgHipAngleRight,
        'avg_knee_angle_left': avgKneeAngleLeft,
        'avg_knee_angle_right': avgKneeAngleRight,
        'avg_ankle_angle_left': avgAnkleAngleLeft,
        'avg_ankle_angle_right': avgAnkleAngleRight,
      };

  factory GaitSummary.fromJson(Map<String, dynamic> json) => GaitSummary(
        totalSteps: json['total_steps'] as int,
        cadenceSpm: (json['cadence_spm'] as num).toDouble(),
        durationSec: (json['duration_sec'] as num).toDouble(),
        avgHipAngleLeft: (json['avg_hip_angle_left'] as num?)?.toDouble(),
        avgHipAngleRight: (json['avg_hip_angle_right'] as num?)?.toDouble(),
        avgKneeAngleLeft: (json['avg_knee_angle_left'] as num?)?.toDouble(),
        avgKneeAngleRight: (json['avg_knee_angle_right'] as num?)?.toDouble(),
        avgAnkleAngleLeft: (json['avg_ankle_angle_left'] as num?)?.toDouble(),
        avgAnkleAngleRight: (json['avg_ankle_angle_right'] as num?)?.toDouble(),
      );
}

class AnalysisResult {
  final VideoMeta videoMeta;
  final Stats stats;
  final List<FrameData> frames;
  final List<GaitEvent> events;
  final GaitSummary summary;
  final List<GaitCycle> cycles;
  final String sportType;

  const AnalysisResult({
    required this.videoMeta,
    required this.stats,
    required this.frames,
    required this.events,
    required this.summary,
    required this.cycles,
    this.sportType = 'running',
  });

  Map<String, dynamic> toJson() => {
        'video_meta': videoMeta.toJson(),
        'stats': stats.toJson(),
        'frames': frames.map((f) => f.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'summary': summary.toJson(),
        'cycles': cycles.map((c) => c.toJson()).toList(),
        'sport_type': sportType,
      };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        videoMeta: VideoMeta.fromJson(json['video_meta'] as Map<String, dynamic>),
        stats: Stats.fromJson(json['stats'] as Map<String, dynamic>),
        frames: (json['frames'] as List<dynamic>)
            .map((f) => FrameData.fromJson(f as Map<String, dynamic>))
            .toList(),
        events: (json['events'] as List<dynamic>)
            .map((e) => GaitEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: GaitSummary.fromJson(json['summary'] as Map<String, dynamic>),
        cycles: (json['cycles'] as List<dynamic>)
            .map((c) => GaitCycle.fromJson(c as Map<String, dynamic>))
            .toList(),
        sportType: json['sport_type'] as String? ?? 'running',
      );
}
