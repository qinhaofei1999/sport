import 'dart:math';
import '../models/pose_landmark.dart';
import '../models/frame_data.dart';
import '../models/gait_event.dart';
import '../models/gait_cycle.dart';
import '../models/analysis_result.dart';
import '../utils/angle_calculator.dart';

class GaitAnalysisService {
  static const int _lAnkle = 27;
  static const int _rAnkle = 28;

  AnalysisResult analyze({
    required List<List<PoseLandmark>?> frameLandmarks,
    required double fps,
    int totalFrames = 0,
    int width = 0,
    int height = 0,
  }) {
    final frames = _buildFrames(frameLandmarks, fps);
    final lAnkleY = _extractSignal(frameLandmarks, _lAnkle, 'y');
    final rAnkleY = _extractSignal(frameLandmarks, _rAnkle, 'y');
    final smoothedL = _smoothSignal(lAnkleY);
    final smoothedR = _smoothSignal(rAnkleY);
    final leftPeaks = _detectPeaks(smoothedL, fps);
    final rightPeaks = _detectPeaks(smoothedR, fps);

    final events = <GaitEvent>[];
    for (final p in leftPeaks) {
      events.add(GaitEvent(
        eventId: 0,
        frame: p,
        timestamp: p / fps,
        side: 'left',
        eventType: 'heel_strike',
      ));
    }
    for (final p in rightPeaks) {
      events.add(GaitEvent(
        eventId: 0,
        frame: p,
        timestamp: p / fps,
        side: 'right',
        eventType: 'heel_strike',
      ));
    }
    events.sort((a, b) => a.frame.compareTo(b.frame));
    for (int i = 0; i < events.length; i++) {
      events[i] = GaitEvent(
        eventId: i,
        frame: events[i].frame,
        timestamp: events[i].timestamp,
        side: events[i].side,
        eventType: events[i].eventType,
      );
    }

    final totalSteps = events.length;
    final duration = frames.isNotEmpty
        ? frames.last.timestamp - frames.first.timestamp
        : 0.0;
    final cadence = duration > 0 && totalSteps >= 2
        ? double.parse(((totalSteps / duration) * 60).toStringAsFixed(1))
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

    final cycles = <GaitCycle>[];
    for (int i = 0; i < events.length - 1; i++) {
      final e0 = events[i];
      final e1 = events[i + 1];
      final cycleDur = e1.timestamp - e0.timestamp;
      cycles.add(GaitCycle(
        cycleId: i,
        startFrame: e0.frame,
        endFrame: e1.frame,
        durationSec: double.parse(cycleDur.toStringAsFixed(3)),
        cadenceSpm: cycleDur > 0
            ? double.parse((60.0 / cycleDur).toStringAsFixed(1))
            : null,
      ));
    }

    final summary = GaitSummary(
      totalSteps: totalSteps,
      cadenceSpm: cadence,
      durationSec: double.parse(duration.toStringAsFixed(2)),
      avgHipAngleLeft: avgAngle('hip_left'),
      avgHipAngleRight: avgAngle('hip_right'),
      avgKneeAngleLeft: avgAngle('knee_left'),
      avgKneeAngleRight: avgAngle('knee_right'),
      avgAnkleAngleLeft: avgAngle('ankle_left'),
      avgAnkleAngleRight: avgAngle('ankle_right'),
    );

    return AnalysisResult(
      videoMeta: VideoMeta(
        filename: 'camera_capture',
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
        cadenceSpm: cadence,
      ),
      frames: frames,
      events: events,
      summary: summary,
      cycles: cycles,
      sportType: 'running',
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
        switch (attr) {
          case 'y':
            return lm.y;
          case 'x':
            return lm.x;
          default:
            return double.nan;
        }
      } catch (_) {
        return double.nan;
      }
    }).toList();
  }

  List<double> _smoothSignal(List<double> signal) {
    final result = List<double>.from(signal);
    if (signal.length < 5) return result;

    for (int i = 2; i < signal.length - 2; i++) {
      if (signal[i].isNaN) continue;
      int count = 0;
      double sum = 0;
      for (int j = -2; j <= 2; j++) {
        if (!signal[i + j].isNaN) {
          sum += signal[i + j];
          count++;
        }
      }
      if (count > 0) {
        result[i] = sum / count;
      }
    }
    return result;
  }

  List<int> _detectPeaks(List<double> signal, double fps,
      {double heightRatio = 0.3, double distanceSec = 0.15}) {
    final clean = signal.map((v) => v.isNaN ? 0.0 : v).toList();
    if (clean.length < 10) return [];

    final mean = clean.reduce((a, b) => a + b) / clean.length;
    final variance =
        clean.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            clean.length;
    final std = sqrt(variance);
    final height = mean + std * heightRatio;
    final distanceFrames = max(1, (distanceSec * fps).round());

    final peaks = <int>[];
    for (int i = 1; i < clean.length - 1; i++) {
      if (clean[i] > height &&
          clean[i] > clean[i - 1] &&
          clean[i] >= clean[i + 1]) {
        if (peaks.isEmpty || i - peaks.last >= distanceFrames) {
          peaks.add(i);
        } else if (clean[i] > clean[peaks.last]) {
          peaks.last = i;
        }
      }
    }
    return peaks;
  }
}
