import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'draggable_resizable_box.dart';

class SnapshotEditor extends StatefulWidget {
  final Uint8List imageBytes;
  final Rect initialBox;
  final Color color;
  final bool isScanning;
  final Function(Rect) onBoxChanged;
  final Function(Rect)? onStable;
  final double bottomOffset;
  final bool isMenuVisible;

  const SnapshotEditor({
    super.key,
    required this.imageBytes,
    required this.initialBox,
    required this.color,
    required this.isScanning,
    required this.onBoxChanged,
    required this.isMenuVisible,
    this.onStable,
    this.bottomOffset = 280.0,
  });

  @override
  State<SnapshotEditor> createState() => _SnapshotEditorState();
}

class _SnapshotEditorState extends State<SnapshotEditor> with SingleTickerProviderStateMixin {
  bool _isStable = true;
  TransformationController _transformationController = TransformationController();
  late Rect initialBox;
  late AnimationController _checkController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    initialBox = widget.initialBox;
    super.initState();

    // Initialize animation controller
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Scale animation with bounce effect
    _scaleAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(widget.isMenuVisible);
    return Stack(
      fit: StackFit.expand,
      children: [
        // IMAGE LAYER with InteractiveViewer
        InteractiveViewer(
          transformationController: _transformationController,
          panEnabled: true,
          scaleEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          child: Image.memory(
            widget.imageBytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // BOX OVERLAY - Fixed on top
        DraggableResizableBox(
          initialBox: initialBox,
          color: widget.color,
          isScanning: widget.isScanning,
          onBoxChanged: (rec) {
            setState(() {
              initialBox = rec;
              if (_isStable) {
                _isStable = false;
                _checkController.reverse();
              }
            });
            widget.onBoxChanged(rec);
          },
          onStable: (box) {
            setState(() {
              _isStable = true;
            });
            _checkController.forward();
          },
        ),

        // CHECK BUTTON - Shows on top of box when stable
        if (_isStable && !widget.isMenuVisible && initialBox != null)
          Positioned(
            left: initialBox.center.dx - 15,
            top: initialBox.top - 40,
            child: AnimatedBuilder(
              animation: _checkController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onStable?.call(initialBox);
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: const Center(
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}