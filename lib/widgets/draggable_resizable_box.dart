import 'package:flutter/material.dart';

class DraggableResizableBox extends StatefulWidget {
  final Rect initialBox;
  final Color color;
  final bool isScanning;
  final Function(Rect) onBoxChanged;

  const DraggableResizableBox({
    super.key,
    required this.initialBox,
    required this.color,
    required this.isScanning,
    required this.onBoxChanged,
  });

  @override
  State<DraggableResizableBox> createState() => _DraggableResizableBoxState();
}

class _DraggableResizableBoxState extends State<DraggableResizableBox>
    with SingleTickerProviderStateMixin {
  late Rect currentBox;
  late AnimationController _scanController;
  final double padding = 40.0;
  final double minSize = 100.0; // Minimum box size

  @override
  void initState() {
    super.initState();
    currentBox = Rect.fromCenter(
      center: widget.initialBox.center,
      width: widget.initialBox.width + (padding * 2),
      height: widget.initialBox.height + (padding * 2),
    );

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(DraggableResizableBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBox != widget.initialBox) {
      setState(() {
        currentBox = Rect.fromCenter(
          center: widget.initialBox.center,
          width: widget.initialBox.width,
          height: widget.initialBox.height,
        );
      });
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details, HandlePosition position) {
    setState(() {
      final delta = details.delta;
      final screenSize = MediaQuery.of(context).size;
      Rect newBox;

      switch (position) {
        case HandlePosition.topLeft:
          newBox = Rect.fromLTRB(
            currentBox.left + delta.dx,
            currentBox.top + delta.dy,
            currentBox.right,
            currentBox.bottom,
          );
          break;
        case HandlePosition.topRight:
          newBox = Rect.fromLTRB(
            currentBox.left,
            currentBox.top + delta.dy,
            currentBox.right + delta.dx,
            currentBox.bottom,
          );
          break;
        case HandlePosition.bottomLeft:
          newBox = Rect.fromLTRB(
            currentBox.left + delta.dx,
            currentBox.top,
            currentBox.right,
            currentBox.bottom + delta.dy,
          );
          break;
        case HandlePosition.bottomRight:
          newBox = Rect.fromLTRB(
            currentBox.left,
            currentBox.top,
            currentBox.right + delta.dx,
            currentBox.bottom + delta.dy,
          );
          break;
        case HandlePosition.center:
          newBox = currentBox.translate(delta.dx, delta.dy);
          break;
      }

      // Apply constraints
      newBox = _constrainBox(newBox, screenSize);
      currentBox = newBox;
      widget.onBoxChanged(currentBox);
    });
  }

  Rect _constrainBox(Rect box, Size screenSize) {
    // Ensure minimum size
    double width = box.width.clamp(minSize, screenSize.width);
    double height = box.height.clamp(minSize, screenSize.height);

    // Ensure box stays within screen bounds
    double left = box.left.clamp(0.0, screenSize.width - width);
    double top = box.top.clamp(0.0, screenSize.height - height);

    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark overlay with cutout - FULL SCREEN
        Positioned.fill(
          child: CustomPaint(
            painter: OverlayPainter(currentBox),
          ),
        ),

        // Scanning animation
        if (widget.isScanning)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ScanningPainter(
                    currentBox,
                    widget.color,
                    _scanController.value,
                  ),
                );
              },
            ),
          ),

        // Box border
        Positioned.fill(
          child: CustomPaint(
            painter: BoxBorderPainter(currentBox, widget.color),
          ),
        ),

        // Center drag handle
        Positioned(
          left: currentBox.left,
          top: currentBox.top,
          child: GestureDetector(
            onPanUpdate: (details) => _handlePanUpdate(details, HandlePosition.center),
            child: Container(
              width: currentBox.width,
              height: currentBox.height,
              color: Colors.transparent,
            ),
          ),
        ),

        // Corner handles
        _buildCornerHandle(HandlePosition.topLeft),
        _buildCornerHandle(HandlePosition.topRight),
        _buildCornerHandle(HandlePosition.bottomLeft),
        _buildCornerHandle(HandlePosition.bottomRight),
      ],
    );
  }

  Widget _buildCornerHandle(HandlePosition position) {
    Offset offset;

    switch (position) {
      case HandlePosition.topLeft:
        offset = Offset(currentBox.left - 20, currentBox.top - 20);
        break;
      case HandlePosition.topRight:
        offset = Offset(currentBox.right - 20, currentBox.top - 20);
        break;
      case HandlePosition.bottomLeft:
        offset = Offset(currentBox.left - 20, currentBox.bottom - 20);
        break;
      case HandlePosition.bottomRight:
        offset = Offset(currentBox.right - 20, currentBox.bottom - 20);
        break;
      case HandlePosition.center:
        return const SizedBox.shrink();
    }

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) => _handlePanUpdate(details, position),
        child: Container(
          width: 40,
          height: 40,
          color: Colors.transparent,
          child: CustomPaint(
            painter: CornerHandlePainter(widget.color, position),
          ),
        ),
      ),
    );
  }
}

enum HandlePosition { topLeft, topRight, bottomLeft, bottomRight, center }

class OverlayPainter extends CustomPainter {
  final Rect box;

  OverlayPainter(this.box);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw transparent black overlay everywhere
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Cut out the annotated box area
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(10)));

    final finalPath = Path.combine(PathOperation.difference, overlayPath, cutoutPath);
    canvas.drawPath(finalPath, Paint()..color = Colors.black.withOpacity(0.7));
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) => box != oldDelegate.box;
}

class BoxBorderPainter extends CustomPainter {
  final Rect box;
  final Color color;

  BoxBorderPainter(this.box, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(10)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BoxBorderPainter oldDelegate) => box != oldDelegate.box;
}

class ScanningPainter extends CustomPainter {
  final Rect box;
  final Color color;
  final double progress;

  ScanningPainter(this.box, this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final scanY = box.top + (box.height * progress);

    final scanPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 20.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawLine(
      Offset(box.left, scanY),
      Offset(box.right, scanY),
      glowPaint,
    );

    canvas.drawLine(
      Offset(box.left, scanY),
      Offset(box.right, scanY),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScanningPainter oldDelegate) => progress != oldDelegate.progress;
}

class CornerHandlePainter extends CustomPainter {
  final Color color;
  final HandlePosition position;

  CornerHandlePainter(this.color, this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final length = 25.0;
    final offset = 10.0;
    final radius = 8.0;

    switch (position) {
      case HandlePosition.topLeft:
        final path = Path()
          ..moveTo(offset + length, offset)
          ..lineTo(offset + radius, offset)
          ..arcToPoint(
            Offset(offset, offset + radius),
            radius: Radius.circular(radius),
            clockwise: false,
          )
          ..lineTo(offset, offset + length);
        canvas.drawPath(path, paint);
        break;

      case HandlePosition.topRight:
        final path = Path()
          ..moveTo(size.width - offset - length, offset)
          ..lineTo(size.width - offset - radius, offset)
          ..arcToPoint(
            Offset(size.width - offset, offset + radius),
            radius: Radius.circular(radius),
          )
          ..lineTo(size.width - offset, offset + length);
        canvas.drawPath(path, paint);
        break;

      case HandlePosition.bottomLeft:
        final path = Path()
          ..moveTo(offset, size.height - offset - length)
          ..lineTo(offset, size.height - offset - radius)
          ..arcToPoint(
            Offset(offset + radius, size.height - offset),
            radius: Radius.circular(radius),
            clockwise: false,
          )
          ..lineTo(offset + length, size.height - offset);
        canvas.drawPath(path, paint);
        break;

      case HandlePosition.bottomRight:
        final path = Path()
          ..moveTo(size.width - offset, size.height - offset - length)
          ..lineTo(size.width - offset, size.height - offset - radius)
          ..arcToPoint(
            Offset(size.width - offset - radius, size.height - offset),
            radius: Radius.circular(radius),
          )
          ..lineTo(size.width - offset - length, size.height - offset);
        canvas.drawPath(path, paint);
        break;

      case HandlePosition.center:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CornerHandlePainter oldDelegate) => false;
}