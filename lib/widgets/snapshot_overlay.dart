import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SnapshotOverlay extends StatefulWidget {
  final Widget imageWidget;
  final Rect initialBox;
  final Size imageSize;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const SnapshotOverlay({
    super.key,
    required this.imageWidget,
    required this.initialBox,
    required this.imageSize,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SnapshotOverlay> createState() => _SnapshotOverlayState();
}

class _SnapshotOverlayState extends State<SnapshotOverlay> {
  late Rect _currentBox;
  Offset? _dragStart;
  Rect? _dragStartBox;

  @override
  void initState() {
    super.initState();
    _currentBox = widget.initialBox;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Snapshot image
        widget.imageWidget,

        // Adjustable box overlay
        GestureDetector(
          onPanStart: (details) {
            _dragStart = details.localPosition;
            _dragStartBox = _currentBox;
          },
          onPanUpdate: (details) {
            if (_dragStart != null && _dragStartBox != null) {
              final delta = details.localPosition - _dragStart!;
              setState(() {
                _currentBox = _dragStartBox!.shift(delta);
              });
            }
          },
          onPanEnd: (_) {
            _dragStart = null;
            _dragStartBox = null;
          },
          child: CustomPaint(
            painter: AdjustableBoxPainter(_currentBox, primaryColor),
          ),
        ),

        // Action buttons at top
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(
                icon: Icons.close,
                onTap: widget.onCancel,
                color: Colors.red,
              ),
              _buildActionButton(
                icon: Icons.check,
                onTap: widget.onConfirm,
                color: primaryColor,
              ),
            ],
          ),
        ),

        // Instruction text
        Positioned(
          bottom: 200,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Drag to adjust • Tap ✓ to continue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class AdjustableBoxPainter extends CustomPainter {
  final Rect box;
  final Color color;

  AdjustableBoxPainter(this.box, this.color);

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

    // Corner handles
    final handlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final handleSize = 12.0;
    final corners = [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, handleSize / 2, handlePaint);
      canvas.drawCircle(
        corner,
        handleSize / 2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AdjustableBoxPainter oldDelegate) {
    return box != oldDelegate.box;
  }
}