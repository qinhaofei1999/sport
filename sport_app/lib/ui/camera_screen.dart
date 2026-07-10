import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as ml;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io' as io;
import '../models/pose_landmark.dart' as pm;
import '../services/pose_detector_service.dart';
import '../services/gait_analysis_service.dart';
import '../services/swimming_analysis_service.dart';
import '../utils/angle_calculator.dart';
import '../utils/pose_painter.dart';
import '../models/analysis_result.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final String sportType;

  const CameraScreen({super.key, required this.sportType});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  PoseDetectorService? _poseService;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isAnalyzing = false;

  final List<List<pm.PoseLandmark>?> _frameLandmarks = [];
  int _frameCount = 0;
  List<pm.PoseLandmark>? _currentLandmarks;
  Map<String, double?>? _currentAngles;
  final double _fps = 30;
  Size? _cameraSize;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _poseService = PoseDetectorService();
    _poseService!.initialize();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    _cameraSize = Size(
      _cameraController!.value.previewSize!.width,
      _cameraController!.value.previewSize!.height,
    );

    setState(() => _isInitialized = true);
  }

  void _toggleRecording() async {
    if (_isRecording) {
      setState(() => _isRecording = false);
      _cameraController?.stopImageStream();
      _runAnalysis();
    } else {
      _frameLandmarks.clear();
      _frameCount = 0;
      _currentLandmarks = null;
      _currentAngles = null;

      _cameraController!.startImageStream(_processImage);
      setState(() => _isRecording = true);
    }
  }

  void _processImage(CameraImage image) {
    if (!_isRecording || _poseService == null || _poseService!.isProcessing) {
      return;
    }

    final cameraSize = _cameraController?.value.previewSize;
    if (cameraSize == null) return;

    final rotation = _getCameraRotation();

    _poseService!.processCameraImage(
      image,
      inputImageWidth: cameraSize.width.round(),
      inputImageHeight: cameraSize.height.round(),
      rotation: rotation,
    ).then((landmarks) {
      if (!mounted) return;
      _frameCount++;

      if (landmarks != null && landmarks.isNotEmpty) {
        final angles = AngleCalculator.calcJointAngles(landmarks);
        _currentLandmarks = landmarks;

        if (mounted) {
          setState(() {
            _currentAngles = angles;
          });
        }
        _frameLandmarks.add(landmarks);
      } else {
        _frameLandmarks.add(null);
      }
    });
  }

  ml.InputImageRotation _getCameraRotation() {
    return ml.InputImageRotation.rotation0deg;
  }

  Future<void> _runAnalysis() async {
    setState(() => _isAnalyzing = true);

    await Future.delayed(const Duration(milliseconds: 100));

    if (_frameLandmarks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未检测到姿态数据')),
        );
        Navigator.pop(context);
      }
      return;
    }

    AnalysisResult result;

    if (widget.sportType == 'running') {
      final gaitService = GaitAnalysisService();
      result = gaitService.analyze(
        frameLandmarks: _frameLandmarks,
        fps: _fps,
        totalFrames: _frameCount,
        width: _cameraSize?.width.round() ?? 0,
        height: _cameraSize?.height.round() ?? 0,
      );
    } else {
      final swimService = SwimmingAnalysisService();
      result = swimService.analyze(
        frameLandmarks: _frameLandmarks,
        fps: _fps,
        totalFrames: _frameCount,
        width: _cameraSize?.width.round() ?? 0,
        height: _cameraSize?.height.round() ?? 0,
      );
    }

    await _saveResult(result);

    if (mounted) {
      setState(() => _isAnalyzing = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    }
  }

  Future<void> _saveResult(AnalysisResult result) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = io.File('${dir.path}/result_$timestamp.json');
      final json = const JsonEncoder.withIndent('  ').convert(result.toJson());
      await file.writeAsString(json);
    } catch (_) {}
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isInitialized && _cameraController != null)
              _buildCameraPreview()
            else
              const Center(child: CircularProgressIndicator()),

            _buildOverlay(),

            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.sportType == 'running' ? '🏃 跑步' : '🏊 游泳',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),

            if (_isRecording)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(180),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'REC $_frameCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_isAnalyzing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.cyanAccent),
                      SizedBox(height: 16),
                      Text(
                        '正在分析...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),

            if (_currentAngles != null && _isRecording)
              Positioned(
                bottom: 100,
                left: 12,
                child: _buildAngleBadge(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final cameraPreview = _cameraController!.buildPreview();

    if (_currentLandmarks != null) {
      return ClipRect(
        child: Stack(
          children: [
            cameraPreview,
            Positioned.fill(
              child: CustomPaint(
                painter: PosePainter(
                  landmarks: _currentLandmarks,
                  angles: _currentAngles,
                  imageSize: _cameraSize ?? const Size(640, 480),
                  sportType: widget.sportType,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return cameraPreview;
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GridPainter(),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleRecording,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: _isRecording ? Colors.red : Colors.white.withAlpha(40),
            ),
            child: Center(
              child: Container(
                width: _isRecording ? 28 : 56,
                height: _isRecording ? 28 : 56,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: _isRecording
                      ? BorderRadius.circular(4)
                      : BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAngleBadge() {
    final kneeL = _currentAngles!['knee_left'];
    final kneeR = _currentAngles!['knee_right'];
    final ankleL = _currentAngles!['ankle_left'];
    final ankleR = _currentAngles!['ankle_right'];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _angleRow('左膝', kneeL, Colors.lightGreen),
          _angleRow('右膝', kneeR, Colors.orange),
          _angleRow('左踝', ankleL, Colors.lightGreen),
          _angleRow('右踝', ankleR, Colors.orange),
        ],
      ),
    );
  }

  Widget _angleRow(String label, double? value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Text(
            value != null ? '${value.toStringAsFixed(0)}°' : '--°',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += size.width / 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += size.height / 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
