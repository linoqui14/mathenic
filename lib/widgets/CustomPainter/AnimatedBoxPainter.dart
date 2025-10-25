import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AnimatedBoxPainter extends CustomPainter {
  final Rect box;
  final Color color;
  final double scale;

  AnimatedBoxPainter(this.box, this.color, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final center = box.center;

    // Add padding to make box bigger
    final padding = 40.0;
    final paddedBox = Rect.fromCenter(
      center: center,
      width: (box.width + padding * 2) * scale,
      height: (box.height + padding * 2) * scale,
    );

    // Draw black overlay everywhere except the detected area
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cornerRadius = 20.0;
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(paddedBox, Radius.circular(cornerRadius)));

    final finalPath = Path.combine(PathOperation.difference, path, cutoutPath);
    canvas.drawPath(finalPath, overlayPaint);

    // Draw subtle fill inside the box
    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final roundedRect = RRect.fromRectAndRadius(paddedBox, Radius.circular(cornerRadius));
    canvas.drawRRect(roundedRect, fillPaint);

    // Draw colored corner accents only
    final accentPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final cornerLength = 40.0;
    final offset = 8.0;
  }

  @override
  bool shouldRepaint(covariant AnimatedBoxPainter oldDelegate) {
    return box != oldDelegate.box || scale != oldDelegate.scale;
  }
}