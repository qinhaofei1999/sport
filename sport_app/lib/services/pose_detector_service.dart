import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as ml;
import '../models/pose_landmark.dart' as pm;

class PoseDetectorService {
  ml.PoseDetector? _detector;
  bool _isProcessing = false;

  void initialize({ml.PoseDetectionMode mode = ml.PoseDetectionMode.stream}) {
    _detector = ml.PoseDetector(
      options: ml.PoseDetectorOptions(
        mode: mode,
        model: ml.PoseDetectionModel.base,
      ),
    );
    _isProcessing = false;
  }

  bool get isProcessing => _isProcessing;

  Future<List<pm.PoseLandmark>?> processImageFile(String filePath) async {
    if (_detector == null) return null;

    _isProcessing = true;
    try {
      final inputImage = ml.InputImage.fromFilePath(filePath);
      final poses = await _detector!.processImage(inputImage);
      if (poses.isEmpty) return null;

      final landmarks = poses.first.landmarks;
      final result = landmarks.entries.map((e) {
        final land = e.value;
        final typeIndex = _poseLandmarkTypeIndex(land.type);
        return pm.PoseLandmark(
          id: typeIndex,
          name: land.type.name,
          x: land.x,
          y: land.y,
          z: land.z,
          visibility: land.likelihood,
        );
      }).toList();

      return result;
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<pm.PoseLandmark>?> processCameraImage(
    CameraImage image, {
    required int inputImageWidth,
    required int inputImageHeight,
    required ml.InputImageRotation rotation,
  }) async {
    if (_isProcessing || _detector == null) return null;

    _isProcessing = true;
    try {
      final inputImage = _buildInputImage(
        image,
        width: inputImageWidth,
        height: inputImageHeight,
        rotation: rotation,
      );
      if (inputImage == null) return null;

      final poses = await _detector!.processImage(inputImage);
      if (poses.isEmpty) return null;

      final landmarks = poses.first.landmarks;
      final result = landmarks.entries.map((e) {
        final land = e.value;
        final typeIndex = _poseLandmarkTypeIndex(land.type);
        return pm.PoseLandmark(
          id: typeIndex,
          name: land.type.name,
          x: land.x,
          y: land.y,
          z: land.z,
          visibility: land.likelihood,
        );
      }).toList();

      return result;
    } finally {
      _isProcessing = false;
    }
  }

  ml.InputImage? _buildInputImage(
    CameraImage image, {
    required int width,
    required int height,
    required ml.InputImageRotation rotation,
  }) {
    if (Platform.isAndroid) {
      return ml.InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: ml.InputImageMetadata(
          size: ui.Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: ml.InputImageFormat.yuv_420_888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else if (Platform.isIOS) {
      return ml.InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: ml.InputImageMetadata(
          size: ui.Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: ml.InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
    return null;
  }

  int _poseLandmarkTypeIndex(ml.PoseLandmarkType type) {
    const typeMap = {
      ml.PoseLandmarkType.nose: 0,
      ml.PoseLandmarkType.leftEyeInner: 1,
      ml.PoseLandmarkType.leftEye: 2,
      ml.PoseLandmarkType.leftEyeOuter: 3,
      ml.PoseLandmarkType.rightEyeInner: 4,
      ml.PoseLandmarkType.rightEye: 5,
      ml.PoseLandmarkType.rightEyeOuter: 6,
      ml.PoseLandmarkType.leftEar: 7,
      ml.PoseLandmarkType.rightEar: 8,
      ml.PoseLandmarkType.leftMouth: 9,
      ml.PoseLandmarkType.rightMouth: 10,
      ml.PoseLandmarkType.leftShoulder: 11,
      ml.PoseLandmarkType.rightShoulder: 12,
      ml.PoseLandmarkType.leftElbow: 13,
      ml.PoseLandmarkType.rightElbow: 14,
      ml.PoseLandmarkType.leftWrist: 15,
      ml.PoseLandmarkType.rightWrist: 16,
      ml.PoseLandmarkType.leftPinky: 17,
      ml.PoseLandmarkType.rightPinky: 18,
      ml.PoseLandmarkType.leftIndex: 19,
      ml.PoseLandmarkType.rightIndex: 20,
      ml.PoseLandmarkType.leftThumb: 21,
      ml.PoseLandmarkType.rightThumb: 22,
      ml.PoseLandmarkType.leftHip: 23,
      ml.PoseLandmarkType.rightHip: 24,
      ml.PoseLandmarkType.leftKnee: 25,
      ml.PoseLandmarkType.rightKnee: 26,
      ml.PoseLandmarkType.leftAnkle: 27,
      ml.PoseLandmarkType.rightAnkle: 28,
      ml.PoseLandmarkType.leftHeel: 29,
      ml.PoseLandmarkType.rightHeel: 30,
      ml.PoseLandmarkType.leftFootIndex: 31,
      ml.PoseLandmarkType.rightFootIndex: 32,
    };
    return typeMap[type] ?? type.index;
  }

  void dispose() {
    _detector?.close();
    _detector = null;
  }
}
