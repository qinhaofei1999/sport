import 'package:flutter/material.dart';
import '../models/pose_landmark.dart';

class PosePainter extends CustomPainter {
  final List<PoseLandmark>? landmarks;
  final Map<String, double?>? angles;
  final Size imageSize;
  final String? sportType;

  static const _bodyConnections = [
    [11, 12],
    [11, 23],
    [12, 24],
    [23, 24],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
    [23, 25],
    [25, 27],
    [24, 26],
    [26, 28],
  ];

  static const _bodyLandmarkIds = {
    11, 12, 13, 14, 15, 16,
    23, 24, 25, 26, 27, 28,
  };

  PosePainter({
    this.landmarks,
    this.angles,
    required this.imageSize,
    this.sportType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null || landmarks!.isEmpty) return;

    final bool pixelCoords =
        landmarks!.any((l) => l.x > 1.0 || l.y > 1.0);

    final lm = <int, PoseLandmark>{};
    for (final l in landmarks!) {
      lm[l.id] = l;
    }

    final upperConnections = [
      [11, 12],
      [11, 13],
      [13, 15],
      [12, 14],
      [14, 16],
    ];

    final torsoConnections = [
      [11, 23],
      [12, 24],
      [23, 24],
    ];

    final lowerConnections = [
      [23, 25],
      [25, 27],
      [24, 26],
      [26, 28],
    ];

    void drawConns(List<List<int>> conns, Color color) {
      for (final conn in conns) {
        final p1 = lm[conn[0]];
        final p2 = lm[conn[1]];
        if (p1 == null || p2 == null) continue;
        if (p1.visibility < 0.1 || p2.visibility < 0.1) continue;

        final pos1 = _toDisplay(p1.x, p1.y, size, pixelCoords);
        final pos2 = _toDisplay(p2.x, p2.y, size, pixelCoords);

        canvas.drawLine(
          pos1,
          pos2,
          Paint()
            ..color = color
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    drawConns(upperConnections, Colors.cyan.withAlpha(200));
    drawConns(torsoConnections, Colors.white.withAlpha(180));
    drawConns(lowerConnections, Colors.greenAccent.withAlpha(200));

    for (final l in landmarks!) {
      if (l.visibility < 0.1) continue;
      if (!_bodyLandmarkIds.contains(l.id)) continue;

      final pos = _toDisplay(l.x, l.y, size, pixelCoords);

      final bool isLower = l.id >= 23;
      canvas.drawCircle(
        pos,
        6,
        Paint()
          ..color = isLower ? Colors.greenAccent : Colors.cyan
          ..style = PaintingStyle.fill,
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

        int? anchorId;
        if (key == 'knee_left') anchorId = 25;
        if (key == 'knee_right') anchorId = 26;
        if (key == 'ankle_left') anchorId = 27;
        if (key == 'ankle_right') anchorId = 28;
        if (key == 'hip_left') anchorId = 23;
        if (key == 'hip_right') anchorId = 24;

        final anchorLm = lm[anchorId!];
        if (anchorLm == null) continue;
        final anchor = _toDisplay(anchorLm.x, anchorLm.y, size, pixelCoords);

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

  Offset _toDisplay(double x, double y, Size displaySize, bool pixelCoords) {
    if (pixelCoords) {
      double normW, normH;
      if (y > imageSize.height || x > imageSize.width) {
        normW = imageSize.height;
        normH = imageSize.width;
      } else {
        normW = imageSize.width;
        normH = imageSize.height;
      }
      final nx = (x / normW).clamp(0.0, 1.0);
      final ny = (y / normH).clamp(0.0, 1.0);
      return Offset(nx * displaySize.width, ny * displaySize.height);
    }
    return Offset(x * displaySize.width, y * displaySize.height);
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
