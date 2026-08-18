import 'package:flutter/material.dart';
import '../models/pose_landmark.dart';

class PosePainter extends CustomPainter {
  final List<PoseLandmark>? landmarks;
  final Map<String, double?>? angles;
  final Size imageSize;
  final String? sportType;

  static const _skeletonConnections = [
    [11, 12],
    [12, 24],
    [24, 23],
    [23, 11],
    [11, 13],
    [13, 15],
    [15, 17],
    [17, 19],
    [19, 15],
    [12, 14],
    [14, 16],
    [16, 18],
    [18, 20],
    [20, 16],
    [23, 25],
    [25, 27],
    [27, 29],
    [29, 31],
    [24, 26],
    [26, 28],
    [28, 30],
    [30, 32],
  ];

  PosePainter({
    this.landmarks,
    this.angles,
    required this.imageSize,
    this.sportType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null || landmarks!.isEmpty) return;

    final bool needRotate = imageSize.width > imageSize.height &&
        size.width < size.height;

    final lm = <int, PoseLandmark>{};
    for (final l in landmarks!) {
      lm[l.id] = l;
    }

    for (final conn in _skeletonConnections) {
      final p1 = lm[conn[0]];
      final p2 = lm[conn[1]];
      if (p1 == null || p2 == null) continue;
      if (p1.visibility < 0.1 || p2.visibility < 0.1) continue;

      final pos1 = _map(_normX(p1.x), _normY(p1.y), size, needRotate);
      final pos2 = _map(_normX(p2.x), _normY(p2.y), size, needRotate);

      canvas.drawLine(
        pos1,
        pos2,
        Paint()
          ..color = Colors.cyan.withAlpha(200)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final l in landmarks!) {
      if (l.visibility < 0.1) continue;
      final pos = _map(_normX(l.x), _normY(l.y), size, needRotate);

      canvas.drawCircle(
        pos,
        6,
        Paint()..color = Colors.yellow..style = PaintingStyle.fill,
      );
    }

    if (angles != null) {
      final angleKeys = [
        'knee_left',
        'knee_right',
        'ankle_left',
        'ankle_right',
        'hip_left',
        'hip_right',
      ];

      for (final key in angleKeys) {
        final val = angles![key];
        if (val == null) continue;

        Offset anchor;
        if (key == 'knee_left') {
          anchor = _lmOffset(lm[25], size, needRotate);
        } else if (key == 'knee_right') {
          anchor = _lmOffset(lm[26], size, needRotate);
        } else if (key == 'ankle_left') {
          anchor = _lmOffset(lm[27], size, needRotate);
        } else if (key == 'ankle_right') {
          anchor = _lmOffset(lm[28], size, needRotate);
        } else if (key == 'hip_left') {
          anchor = _lmOffset(lm[23], size, needRotate);
        } else {
          anchor = _lmOffset(lm[24], size, needRotate);
        }

        final text = '${key.split('_').last} ${val.toStringAsFixed(0)}°';
        final textPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: key.contains('left') ? Colors.lightGreen : Colors.orange,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 3),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            anchor.dx - textPainter.width / 2,
            anchor.dy - textPainter.height - 8,
          ),
        );
      }
    }

    if (sportType == 'running') {
      _drawSportBadge(canvas, size);
    }

    final first = landmarks!.first;
    final nx = _normX(first.x);
    final ny = _normY(first.y);
    final pos = _map(nx, ny, size, needRotate);
    final debugPainter = TextPainter(
      text: TextSpan(
        text:
            'raw:(${first.x.toStringAsFixed(1)},${first.y.toStringAsFixed(1)}) n:(${nx.toStringAsFixed(2)},${ny.toStringAsFixed(2)}) map:(${pos.dx.toStringAsFixed(0)},${pos.dy.toStringAsFixed(0)}) rot:$needRotate img:${imageSize.width.toStringAsFixed(0)}x${imageSize.height.toStringAsFixed(0)} w:${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 10,
          backgroundColor: Colors.white70,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    debugPainter.layout();
    debugPainter.paint(canvas, Offset(10, size.height - 30));
  }

  double _normX(double x) {
    if (x <= 1.0) return x;
    final w = imageSize.width > imageSize.height
        ? imageSize.height
        : imageSize.width;
    return (x / w).clamp(0.0, 1.0);
  }

  double _normY(double y) {
    if (y <= 1.0) return y;
    final h = imageSize.width > imageSize.height
        ? imageSize.width
        : imageSize.height;
    return (y / h).clamp(0.0, 1.0);
  }

  Offset _map(double x, double y, Size displaySize, bool rotate90) {
    if (!rotate90) {
      return Offset(x * displaySize.width, y * displaySize.height);
    }
    return Offset(y * displaySize.width, x * displaySize.height);
  }

  Offset _lmOffset(PoseLandmark? lm, Size displaySize, bool rotate90) {
    if (lm == null) return Offset.zero;
    return _map(_normX(lm.x), _normY(lm.y), displaySize, rotate90);
  }

  void _drawSportBadge(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: sportType == 'running' ? 'RUNNING' : 'SWIMMING',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(12, 12));
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
