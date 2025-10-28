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
    final padding = 30.0;
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

    final cornerRadius = 10.0;
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(paddedBox, Radius.circular(cornerRadius)));

    final finalPath = Path.combine(PathOperation.difference, path, cutoutPath);
    canvas.drawPath(finalPath, overlayPaint);

    // Draw subtle fill inside the box
    final fillPaint = Paint()
      ..color = color.withAlpha(100)
      ..style = PaintingStyle.fill;

    final roundedRect = RRect.fromRectAndRadius(paddedBox, Radius.circular(cornerRadius));
    canvas.drawRRect(roundedRect, fillPaint);

    // Draw corner handles with gap from box edge
    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength =  30;
    final handleRadius = 15.0;
    final gap = 6.0; // Space between box and corners

    // Top-left corner
    final topLeftPath = Path()
      ..moveTo(paddedBox.left + cornerLength - gap, paddedBox.top - gap)
      ..lineTo(paddedBox.left + handleRadius - gap, paddedBox.top - gap)
      ..arcToPoint(
        Offset(paddedBox.left - gap, paddedBox.top + handleRadius - gap),
        radius: Radius.circular(handleRadius),
        clockwise: false,
      )
      ..lineTo(paddedBox.left - gap, paddedBox.top + cornerLength - gap);
    canvas.drawPath(topLeftPath, handlePaint);

    // Top-right corner
    final topRightPath = Path()
      ..moveTo(paddedBox.right - cornerLength + gap, paddedBox.top - gap)
      ..lineTo(paddedBox.right - handleRadius + gap, paddedBox.top - gap)
      ..arcToPoint(
        Offset(paddedBox.right + gap, paddedBox.top + handleRadius - gap),
        radius: Radius.circular(handleRadius),
      )
      ..lineTo(paddedBox.right + gap, paddedBox.top + cornerLength - gap);
    canvas.drawPath(topRightPath, handlePaint);

    // Bottom-left corner
    final bottomLeftPath = Path()
      ..moveTo(paddedBox.left - gap, paddedBox.bottom - cornerLength + gap)
      ..lineTo(paddedBox.left - gap, paddedBox.bottom - handleRadius + gap)
      ..arcToPoint(
        Offset(paddedBox.left + handleRadius - gap, paddedBox.bottom + gap),
        radius: Radius.circular(handleRadius),
        clockwise: false,
      )
      ..lineTo(paddedBox.left + cornerLength - gap, paddedBox.bottom + gap);
    canvas.drawPath(bottomLeftPath, handlePaint);

    // Bottom-right corner
    final bottomRightPath = Path()
      ..moveTo(paddedBox.right + gap, paddedBox.bottom - cornerLength + gap)
      ..lineTo(paddedBox.right + gap, paddedBox.bottom - handleRadius + gap)
      ..arcToPoint(
        Offset(paddedBox.right - handleRadius + gap, paddedBox.bottom + gap),
        radius: Radius.circular(handleRadius),
      )
      ..lineTo(paddedBox.right - cornerLength + gap, paddedBox.bottom + gap);
    canvas.drawPath(bottomRightPath, handlePaint);
  }

  @override
  bool shouldRepaint(covariant AnimatedBoxPainter oldDelegate) {
    return box != oldDelegate.box || scale != oldDelegate.scale;
  }
}