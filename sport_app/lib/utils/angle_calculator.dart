import 'dart:math';
import '../models/pose_landmark.dart';

class AngleCalculator {
  static const Map<int, String> landmarkNames = {
    0: 'nose',
    1: 'left_eye_inner',
    2: 'left_eye',
    3: 'left_eye_outer',
    4: 'right_eye_inner',
    5: 'right_eye',
    6: 'right_eye_outer',
    7: 'left_ear',
    8: 'right_ear',
    9: 'mouth_left',
    10: 'mouth_right',
    11: 'left_shoulder',
    12: 'right_shoulder',
    13: 'left_elbow',
    14: 'right_elbow',
    15: 'left_wrist',
    16: 'right_wrist',
    17: 'left_pinky',
    18: 'right_pinky',
    19: 'left_index',
    20: 'right_index',
    21: 'left_thumb',
    22: 'right_thumb',
    23: 'left_hip',
    24: 'right_hip',
    25: 'left_knee',
    26: 'right_knee',
    27: 'left_ankle',
    28: 'right_ankle',
    29: 'left_heel',
    30: 'right_heel',
    31: 'left_foot_index',
    32: 'right_foot_index',
  };

  static double _angleBetween3D(
      double x1, double y1, double z1, double x2, double y2, double z2) {
    final dot = x1 * x2 + y1 * y2 + z1 * z2;
    final norm = sqrt(x1 * x1 + y1 * y1 + z1 * z1) *
        sqrt(x2 * x2 + y2 * y2 + z2 * z2);
    if (norm == 0) return 0.0;
    final cosA = (dot / norm).clamp(-1.0, 1.0);
    return acos(cosA) * 180.0 / pi;
  }

  static double? angle(
      PoseLandmark? p1, PoseLandmark? vertex, PoseLandmark? p2) {
    if (p1 == null || vertex == null || p2 == null) return null;
    final v1x = p1.x - vertex.x;
    final v1y = p1.y - vertex.y;
    final v1z = p1.z - vertex.z;
    final v2x = p2.x - vertex.x;
    final v2y = p2.y - vertex.y;
    final v2z = p2.z - vertex.z;
    final result = _angleBetween3D(v1x, v1y, v1z, v2x, v2y, v2z);
    return double.parse(result.toStringAsFixed(2));
  }

  static double? hipAngle(
      Map<int, PoseLandmark> lm, int shoulderId, int hipId, int kneeId) {
    return angle(lm[shoulderId], lm[hipId], lm[kneeId]);
  }

  static double? kneeAngle(
      Map<int, PoseLandmark> lm, int hipId, int kneeId, int ankleId) {
    return angle(lm[hipId], lm[kneeId], lm[ankleId]);
  }

  static double? ankleAngle(
      Map<int, PoseLandmark> lm, int kneeId, int ankleId, int footId) {
    return angle(lm[kneeId], lm[ankleId], lm[footId]);
  }

  static Map<String, double?> calcJointAngles(List<PoseLandmark> landmarks) {
    final lm = <int, PoseLandmark>{};
    for (final l in landmarks) {
      lm[l.id] = l;
    }
    return {
      'hip_left': hipAngle(lm, 11, 23, 25),
      'hip_right': hipAngle(lm, 12, 24, 26),
      'knee_left': kneeAngle(lm, 23, 25, 27),
      'knee_right': kneeAngle(lm, 24, 26, 28),
      'ankle_left': ankleAngle(lm, 25, 27, 31),
      'ankle_right': ankleAngle(lm, 26, 28, 32),
    };
  }
}
