import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as ml;
import '../models/pose_landmark.dart' as pm;
import '../services/pose_detector_service.dart';
import '../utils/pose_painter.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  File? _imageFile;
  List<pm.PoseLandmark>? _landmarks;
  Size? _imageSize;
  bool _isProcessing = false;
  String? _error;

  final _picker = ImagePicker();
  final _poseService = PoseDetectorService();

  @override
  void initState() {
    super.initState();
    _poseService.initialize(mode: ml.PoseDetectionMode.single);
  }

  @override
  void dispose() {
    _poseService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _landmarks = null;
        _imageSize = null;
        _error = null;
        _isProcessing = true;
      });

      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
      decoded.dispose();

      final landmarks = await _poseService.processImageFile(picked.path);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (landmarks != null) {
            _landmarks = landmarks;
          } else {
            _error = '未检测到任何姿态';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = '错误: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('调试测试', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildButtons(),
          Expanded(
            child: _imageFile == null
                ? const Center(
                    child: Text(
                      '请选择一张有人站立的照片',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : _buildResult(),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('拍照'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('从相册选择'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.cyanAccent),
                  SizedBox(height: 12),
                  Text('正在检测姿态...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
            ),
          if (_imageFile != null && !_isProcessing) _buildImageWithSkeleton(),
          if (_landmarks != null) _buildDebugTable(),
        ],
      ),
    );
  }

  Widget _buildImageWithSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayWidth = constraints.maxWidth;
        final displayHeight = displayWidth * (_imageSize!.height / _imageSize!.width);

        return SizedBox(
          width: displayWidth,
          height: displayHeight,
          child: Stack(
            children: [
              Image.file(_imageFile!, width: displayWidth, height: displayHeight, fit: BoxFit.cover),
              if (_landmarks != null && _imageSize != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: PosePainter(
                      landmarks: _landmarks,
                      imageSize: _imageSize!,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebugTable() {
    final sorted = List<pm.PoseLandmark>.from(_landmarks!);
    sorted.sort((a, b) => a.id.compareTo(b.id));

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '图片尺寸: ${_imageSize?.width.toStringAsFixed(0)} x ${_imageSize?.height.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontFamily: 'monospace'),
                ),
                Text(
                  '检测到 ${_landmarks!.length} 个 landmarks',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            color: Colors.grey[900],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 8,
                headingRowColor: WidgetStateProperty.all(Colors.grey[800]),
                dataRowColor: WidgetStateProperty.all(Colors.grey[900]),
                columns: const [
                  DataColumn(label: Text('ID', style: _headerStyle)),
                  DataColumn(label: Text('部位', style: _headerStyle)),
                  DataColumn(label: Text('raw X', style: _headerStyle)),
                  DataColumn(label: Text('raw Y', style: _headerStyle)),
                  DataColumn(label: Text('raw Z', style: _headerStyle)),
                  DataColumn(label: Text('vis', style: _headerStyle)),
                ],
                rows: sorted.map((l) {
                  final isBody = l.id >= 11 && l.id <= 16 || l.id >= 23 && l.id <= 28;
                  return DataRow(
                    color: WidgetStateProperty.all(
                      isBody ? Colors.blueGrey[900] : Colors.grey[900],
                    ),
                    cells: [
                      DataCell(Text('${l.id}', style: _cellStyle)),
                      DataCell(Text(l.name, style: _cellStyle)),
                      DataCell(Text(l.x.toStringAsFixed(1), style: _cellStyle)),
                      DataCell(Text(l.y.toStringAsFixed(1), style: _cellStyle)),
                      DataCell(Text(l.z.toStringAsFixed(1), style: _cellStyle)),
                      DataCell(Text(l.visibility.toStringAsFixed(2), style: _cellStyle)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace');
const _cellStyle = TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace');
