import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as ml;
import 'package:path_provider/path_provider.dart';
import '../models/pose_landmark.dart' as pm;

class PoseDetectorService {
  ml.PoseDetector? _detector;
  bool _isProcessing = false;
  File? _tempFile;

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

      return _extractLandmarks(poses);
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
      final filePath = await _saveFrameToTempFile(image);
      if (filePath == null) return null;

      try {
        final inputImage = ml.InputImage.fromFilePath(filePath);
        final poses = await _detector!.processImage(inputImage);
        if (poses.isEmpty) return null;

        return _extractLandmarks(poses);
      } finally {
        _tempFile?.deleteSync();
        _tempFile = null;
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<String?> _saveFrameToTempFile(CameraImage image) async {
    try {
      final plane = image.planes[0];
      final bytes = plane.bytes;
      final bytesPerRow = plane.bytesPerRow;
      final width = image.width;
      final height = image.height;

      final rgba = Uint8List(width * height * 4);
      for (var row = 0; row < height; row++) {
        final rowOffset = row * bytesPerRow;
        final pixelOffset = row * width * 4;
        for (var col = 0; col < width; col++) {
          final srcIdx = rowOffset + col * 4;
          final dstIdx = pixelOffset + col * 4;
          rgba[dstIdx + 0] = bytes[srcIdx + 2]; // R
          rgba[dstIdx + 1] = bytes[srcIdx + 1]; // G
          rgba[dstIdx + 2] = bytes[srcIdx + 0]; // B
          rgba[dstIdx + 3] = bytes[srcIdx + 3]; // A
        }
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgba,
        width,
        height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final uiImage = await completer.future;

      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/sport_frame_${Platform.environment['PROCESS_ID'] ?? '0'}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      _tempFile = file;

      uiImage.dispose();

      return file.path;
    } catch (_) {
      return null;
    }
  }

  List<pm.PoseLandmark> _extractLandmarks(List<ml.Pose> poses) {
    final landmarks = poses.first.landmarks;
    return landmarks.entries.map((e) {
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
    _tempFile?.deleteSync();
    _tempFile = null;
    _detector?.close();
    _detector = null;
  }
}
