
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CenterFramePainter extends CustomPainter {
  final Rect frame;
  final Color color;

  CenterFramePainter(this.frame, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;
    final radius = 12.0;

    // Top-left corner
    final topLeftPath = Path()
      ..moveTo(frame.left, frame.top + cornerLength)
      ..lineTo(frame.left, frame.top + radius)
      ..arcToPoint(
        Offset(frame.left + radius, frame.top),
        radius: Radius.circular(radius),
      )
      ..lineTo(frame.left + cornerLength, frame.top);
    canvas.drawPath(topLeftPath, paint);

    // Top-right corner
    final topRightPath = Path()
      ..moveTo(frame.right - cornerLength, frame.top)
      ..lineTo(frame.right - radius, frame.top)
      ..arcToPoint(
        Offset(frame.right, frame.top + radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(frame.right, frame.top + cornerLength);
    canvas.drawPath(topRightPath, paint);

    // Bottom-left corner
    final bottomLeftPath = Path()
      ..moveTo(frame.left, frame.bottom - cornerLength)
      ..lineTo(frame.left, frame.bottom - radius)
      ..arcToPoint(
        Offset(frame.left + radius, frame.bottom),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(frame.left + cornerLength, frame.bottom);
    canvas.drawPath(bottomLeftPath, paint);

    // Bottom-right corner
    final bottomRightPath = Path()
      ..moveTo(frame.right, frame.bottom - cornerLength)
      ..lineTo(frame.right, frame.bottom - radius)
      ..arcToPoint(
        Offset(frame.right - radius, frame.bottom),
        radius: Radius.circular(radius),
      )
      ..lineTo(frame.right - cornerLength, frame.bottom);
    canvas.drawPath(bottomRightPath, paint);

    // Hint text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Position problem here',
        style: TextStyle(
          color: Colors.white.withAlpha(100),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        frame.center.dx - textPainter.width / 2,
        frame.top - 40,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CenterFramePainter oldDelegate) {
    return frame != oldDelegate.frame;
  }
}