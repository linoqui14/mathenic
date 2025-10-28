import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SnapshotBoxPainter extends CustomPainter {
  final Rect box;
  final Color color;

  SnapshotBoxPainter(this.box, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(16)));

    final finalPath = Path.combine(PathOperation.difference, overlayPath, cutoutPath);
    canvas.drawPath(finalPath, Paint()..color = Colors.black.withOpacity(0.6));

    // Box border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(16)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SnapshotBoxPainter oldDelegate) {
    return box != oldDelegate.box;
  }
}