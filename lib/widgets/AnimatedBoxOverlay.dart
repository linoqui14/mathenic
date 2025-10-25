import 'package:flutter/cupertino.dart';

import 'CustomPainter/AnimatedBoxPainter.dart';

class AnimatedBoxOverlay extends StatefulWidget {
  final Rect targetBox;
  final Rect? currentBox;
  final Function(Rect) onBoxUpdate;
  final Color color;
  final Animation<double> pulseAnimation;

  const AnimatedBoxOverlay({
    super.key,
    required this.targetBox,
    required this.currentBox,
    required this.onBoxUpdate,
    required this.color,
    required this.pulseAnimation,
  });

  @override
  State<AnimatedBoxOverlay> createState() => _AnimatedBoxOverlayState();
}

class _AnimatedBoxOverlayState extends State<AnimatedBoxOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _moveController;
  late Animation<Rect?> _rectAnimation;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _updateAnimation();
  }

  void _updateAnimation() {
    _rectAnimation = RectTween(
      begin: widget.currentBox ?? widget.targetBox,
      end: widget.targetBox,
    ).animate(CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeOutCubic,
    ))..addListener(() {
      if (_rectAnimation.value != null) {
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onBoxUpdate(_rectAnimation.value!);
          }
        });
      }
    });

    _moveController.forward(from: 0);
  }

  @override
  void didUpdateWidget(AnimatedBoxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetBox != widget.targetBox) {
      _updateAnimation();
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_moveController, widget.pulseAnimation]),
      builder: (context, child) {
        final box = _rectAnimation.value ?? widget.targetBox;
        return CustomPaint(
          painter: AnimatedBoxPainter(box, widget.color, widget.pulseAnimation.value),
        );
      },
    );
  }
}