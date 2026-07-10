import 'dart:math';
import '../models/pose_landmark.dart';
import '../models/frame_data.dart';
import '../models/gait_event.dart';
import '../models/analysis_result.dart';
import '../utils/angle_calculator.dart';

class SwimmingAnalysisService {
  static const int _lWrist = 15;
  static const int _rWrist = 16;

  AnalysisResult analyze({
    required List<List<PoseLandmark>?> frameLandmarks,
    required double fps,
    int totalFrames = 0,
    int width = 0,
    int height = 0,
  }) {
    final frames = _buildFrames(frameLandmarks, fps);
    final lWristY = _extractSignal(frameLandmarks, _lWrist, 'y');
    final rWristY = _extractSignal(frameLandmarks, _rWrist, 'y');
    final lWristX = _extractSignal(frameLandmarks, _lWrist, 'x');
    final rWristX = _extractSignal(frameLandmarks, _rWrist, 'x');

    final leftStrokes = _detectStrokes(lWristY, lWristX, fps);
    final rightStrokes = _detectStrokes(rWristY, rWristX, fps);

    final eventList = <Map<String, dynamic>>[];
    for (final p in leftStrokes) {
      eventList.add({
        'frame': p,
        'timestamp': double.parse((p / fps).toStringAsFixed(4)),
        'side': 'left',
        'event_type': 'stroke',
      });
    }
    for (final p in rightStrokes) {
      eventList.add({
        'frame': p,
        'timestamp': double.parse((p / fps).toStringAsFixed(4)),
        'side': 'right',
        'event_type': 'stroke',
      });
    }
    eventList.sort((a, b) => (a['frame'] as int).compareTo(b['frame'] as int));

    final events = eventList.asMap().entries.map((e) {
      return GaitEvent(
        eventId: e.key,
        frame: e.value['frame'] as int,
        timestamp: e.value['timestamp'] as double,
        side: e.value['side'] as String,
        eventType: e.value['event_type'] as String,
      );
    }).toList();

    final totalStrokes = events.length;
    final duration = frames.isNotEmpty
        ? frames.last.timestamp - frames.first.timestamp
        : 0.0;
    final strokeRate = duration > 0 && totalStrokes >= 2
        ? double.parse(((totalStrokes / duration) * 60).toStringAsFixed(1))
        : 0.0;

    final allAngles = frames
        .where((f) => f.detected)
        .map((f) => f.angles)
        .toList();

    double? avgAngle(String key) {
      final vals = allAngles
          .map((a) => a[key])
          .where((v) => v != null)
          .cast<double>()
          .toList();
      if (vals.isEmpty) return null;
      return double.parse(
          (vals.reduce((a, b) => a + b) / vals.length).toStringAsFixed(2));
    }

    return AnalysisResult(
      videoMeta: VideoMeta(
        filename: 'swimming_capture',
        fps: fps,
        totalFrames: totalFrames > 0 ? totalFrames : frames.length,
        durationSec: double.parse(duration.toStringAsFixed(2)),
        width: width,
        height: height,
      ),
      stats: Stats(
        framesProcessed: frames.length,
        framesDetected: frames.where((f) => f.detected).length,
        detectionRate: frames.isNotEmpty
            ? double.parse(
                (frames.where((f) => f.detected).length / frames.length)
                    .toStringAsFixed(4))
            : 0.0,
        gaitEvents: events.length,
        cadenceSpm: strokeRate,
      ),
      frames: frames,
      events: events,
      summary: GaitSummary(
        totalSteps: totalStrokes,
        cadenceSpm: strokeRate,
        durationSec: double.parse(duration.toStringAsFixed(2)),
        avgHipAngleLeft: avgAngle('hip_left'),
        avgHipAngleRight: avgAngle('hip_right'),
        avgKneeAngleLeft: avgAngle('knee_left'),
        avgKneeAngleRight: avgAngle('knee_right'),
        avgAnkleAngleLeft: avgAngle('ankle_left'),
        avgAnkleAngleRight: avgAngle('ankle_right'),
      ),
      cycles: [],
      sportType: 'swimming',
    );
  }

  List<FrameData> _buildFrames(
    List<List<PoseLandmark>?> landmarksList,
    double fps,
  ) {
    final frames = <FrameData>[];
    for (int i = 0; i < landmarksList.length; i++) {
      final lm = landmarksList[i];
      final detected = lm != null && lm.isNotEmpty;
      final angles = detected
          ? AngleCalculator.calcJointAngles(lm)
          : <String, double?>{};
      frames.add(FrameData(
        frame: i,
        timestamp: double.parse((i / fps).toStringAsFixed(4)),
        detected: detected,
        angles: angles,
        landmarks: lm ?? [],
      ));
    }
    return frames;
  }

  List<double> _extractSignal(
    List<List<PoseLandmark>?> frames,
    int landmarkId,
    String attr,
  ) {
    return frames.map((lmList) {
      if (lmList == null || lmList.isEmpty) return double.nan;
      try {
        final lm = lmList.firstWhere((l) => l.id == landmarkId);
        return attr == 'y' ? lm.y : lm.x;
      } catch (_) {
        return double.nan;
      }
    }).toList();
  }

  List<int> _detectStrokes(
    List<double> wristY,
    List<double> wristX,
    double fps,
  ) {
    final cleanY = wristY.map((v) => v.isNaN ? 0.5 : v).toList();
    if (cleanY.length < 10) return [];

    final smoothed = <double>[];
    for (int i = 2; i < cleanY.length - 2; i++) {
      double sum = 0;
      for (int j = -2; j <= 2; j++) {
        sum += cleanY[i + j];
      }
      smoothed.add(sum / 5);
    }

    final mean =
        smoothed.reduce((a, b) => a + b) / smoothed.length;
    final variance =
        smoothed.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            smoothed.length;
    final std = sqrt(variance);
    final threshold = mean - std * 0.5;
    final minDistance = (0.3 * fps).round();

    final strokes = <int>[];
    for (int i = 1; i < smoothed.length - 1; i++) {
      if (smoothed[i] < threshold &&
          smoothed[i] < smoothed[i - 1] &&
          smoothed[i] < smoothed[i + 1]) {
        final actualFrame = i + 2;
        if (strokes.isEmpty ||
            actualFrame - strokes.last >= minDistance) {
          strokes.add(actualFrame);
        }
      }
    }
    return strokes;
  }
}
