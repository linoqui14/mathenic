import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DraggableResizableBox extends StatefulWidget {
  final Rect initialBox;
  final Color color;
  final bool isScanning;
  final Function(Rect) onBoxChanged;
  final Function(Rect)? onStable;
  final Duration stabilityDuration;

  const DraggableResizableBox({
    super.key,
    required this.initialBox,
    required this.color,
    required this.isScanning,
    required this.onBoxChanged,
    this.onStable,
    this.stabilityDuration = const Duration(milliseconds: 500),
  });

  @override
  State<DraggableResizableBox> createState() => _DraggableResizableBoxState();
}

class _DraggableResizableBoxState extends State<DraggableResizableBox>
    with TickerProviderStateMixin {
  late Rect currentBox;
  late AnimationController _scanController;
  late AnimationController _stabilityController;
  final double padding = 30.0;
  final double minSize = 50.0;

  bool _isStable = false;
  bool _isHolding = false;
  Timer? _stabilityTimer;
  DateTime? _lastMoveTime;

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

    _stabilityController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _startStabilityCheck();
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
    _stabilityController.dispose();
    _stabilityTimer?.cancel();
    super.dispose();
  }

  void _startStabilityCheck() {
    _stabilityTimer?.cancel();
    _stabilityTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_lastMoveTime != null) {
        final timeSinceMove = DateTime.now().difference(_lastMoveTime!);
        if (timeSinceMove >= widget.stabilityDuration && !_isStable && !_isHolding) {
          setState(() {
            _isStable = true;
          });
          if(widget.onStable != null) {
            widget.onStable!(currentBox);
          }
          _stabilityController.forward();
          HapticFeedback.heavyImpact();
        }
      }
    });
  }

  void _resetStability() {
    _lastMoveTime = DateTime.now();
    if (_isStable) {
      setState(() {
        _isStable = false;
      });
      _stabilityController.reverse();
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, HandlePosition position) {
    _resetStability();
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

      newBox = _constrainBox(newBox, screenSize);
      currentBox = newBox;
      widget.onBoxChanged(currentBox);
    });
  }

  Rect _constrainBox(Rect box, Size screenSize) {
    double width = box.width.clamp(minSize, screenSize.width);
    double height = box.height.clamp(minSize, screenSize.height);
    double left = box.left.clamp(0.0, screenSize.width - width);
    double top = box.top.clamp(0.0, screenSize.height - height);
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: OverlayPainter(currentBox),
          ),
        ),
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
        Positioned.fill(
            child: CustomPaint(
              painter: StabilityBoxPainter(
                currentBox,
                widget.color,
                _isStable,
              ),
            )
        ),
        Positioned(
          left: currentBox.left,
          top: currentBox.top,
          child: GestureDetector(
            onPanStart: (_) {
              print("Handle pressed - holding");
              setState(() {
                _isHolding = true;
              });
            },
            onPanEnd: (_) {
              print("Handle released");
              setState(() {
                _isHolding = false;
              });
              // Optional: handle release
            },
            onPanUpdate: (details) => _handlePanUpdate(details, HandlePosition.center),
            child: Container(
              width: currentBox.width,
              height: currentBox.height,
              color: Colors.transparent,
            ),
          ),
        ),
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
        onPanStart: (_) {
          print("Handle pressed - holding");
          setState(() {
            _isHolding = true;
          });
        },
        onPanEnd: (_) {
          print("Handle released");
          setState(() {
            _isHolding = false;
          });
          // Optional: handle release
        },
        onPanUpdate: (details) => _handlePanUpdate(details, position),
        child: Container(
          width: 40,
          height: 40,
          color: Colors.transparent,
          child: CustomPaint(
            painter: CornerHandlePainter(
              widget.color,
              position,
              _isStable,
            ),
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
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(10)));

    final finalPath = Path.combine(PathOperation.difference, overlayPath, cutoutPath);
    canvas.drawPath(finalPath, Paint()..color = Colors.black.withOpacity(0.7));
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) => box != oldDelegate.box;
}

class StabilityBoxPainter extends CustomPainter {
  final Rect box;
  final Color color;
  final bool isStable;

  StabilityBoxPainter(this.box, this.color, this.isStable);

  @override
  void paint(Canvas canvas, Size size) {
    final center = box.center;
    final scaledBox = Rect.fromCenter(
      center: center,
      width: box.width,
      height: box.height,
    );

    if (isStable) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledBox, const Radius.circular(10)),
        glowPaint,
      );
    }

    final borderPaint = Paint()
      ..color = isStable ? color : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isStable ? 2.0 : 0.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledBox, const Radius.circular(10)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant StabilityBoxPainter oldDelegate) {
    return box != oldDelegate.box ||
        isStable != oldDelegate.isStable;
  }
}

class ScanningPainter extends CustomPainter {
  final Rect box;
  final Color color;
  final double progress;

  ScanningPainter(this.box, this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final scanY = box.top + (box.height * progress);

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

    final scanPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

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
  final bool isStable;

  CornerHandlePainter(this.color, this.position, this.isStable,);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isStable ? color : Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final length = 30.0;
    final offset = 14.0;
    final radius = 15.0;

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
  bool shouldRepaint(covariant CornerHandlePainter oldDelegate) {
    return isStable != oldDelegate.isStable;
  }
}