import 'dart:math';
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

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scale = min(scaleX, scaleY);
    final offsetX = (size.width - imageSize.width * scale) / 2;
    final offsetY = (size.height - imageSize.height * scale) / 2;

    final lm = <int, PoseLandmark>{};
    for (final l in landmarks!) {
      lm[l.id] = l;
    }

    for (final conn in _skeletonConnections) {
      final p1 = lm[conn[0]];
      final p2 = lm[conn[1]];
      if (p1 == null || p2 == null) continue;
      if (p1.visibility < 0.1 || p2.visibility < 0.1) continue;

      final x1 = p1.x * imageSize.width * scale + offsetX;
      final y1 = p1.y * imageSize.height * scale + offsetY;
      final x2 = p2.x * imageSize.width * scale + offsetX;
      final y2 = p2.y * imageSize.height * scale + offsetY;

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = Colors.cyan.withAlpha(200)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final l in landmarks!) {
      if (l.visibility < 0.1) continue;
      final x = l.x * imageSize.width * scale + offsetX;
      final y = l.y * imageSize.height * scale + offsetY;

      canvas.drawCircle(
        Offset(x, y),
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
          anchor = _lmOffset(lm[25], scale, offsetX, offsetY);
        } else if (key == 'knee_right') {
          anchor = _lmOffset(lm[26], scale, offsetX, offsetY);
        } else if (key == 'ankle_left') {
          anchor = _lmOffset(lm[27], scale, offsetX, offsetY);
        } else if (key == 'ankle_right') {
          anchor = _lmOffset(lm[28], scale, offsetX, offsetY);
        } else if (key == 'hip_left') {
          anchor = _lmOffset(lm[23], scale, offsetX, offsetY);
        } else {
          anchor = _lmOffset(lm[24], scale, offsetX, offsetY);
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
  }

  Offset _lmOffset(PoseLandmark? lm, double scale, double ox, double oy) {
    if (lm == null) return Offset.zero;
    return Offset(
      lm.x * imageSize.width * scale + ox,
      lm.y * imageSize.height * scale + oy,
    );
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
