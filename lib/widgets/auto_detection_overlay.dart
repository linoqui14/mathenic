import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../widgets/animated_box_overlay.dart';

class AutoDetectionOverlay extends StatefulWidget {
  final CameraController cameraController;
  final Animation<double> pulseAnimation;
  final Color color;
  final bool isEnabled;
  final Function(CameraImage, Rect) onStableDetection;

  const AutoDetectionOverlay({
    super.key,
    required this.cameraController,
    required this.pulseAnimation,
    required this.color,
    required this.isEnabled,
    required this.onStableDetection,
  });

  @override
  State<AutoDetectionOverlay> createState() => _AutoDetectionOverlayState();
}

class _AutoDetectionOverlayState extends State<AutoDetectionOverlay> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  Rect? _targetBox;
  Rect? _animatedBox;
  bool _isProcessing = false;
  DateTime? _lastProcessTime;
  Rect? _lastDetectedBox;
  int _stableFrameCount = 0;
  DateTime? _stabilityStartTime;

  static const int _requiredStableFrames = 3;
  static const double _stabilityThreshold = 20.0;
  static const int _stabilityTimeoutSeconds = 2;

  StreamSubscription? _imageStreamSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.isEnabled) {
      _startDetection();
    }
  }

  @override
  void didUpdateWidget(AutoDetectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled != oldWidget.isEnabled) {
      if (widget.isEnabled) {
        _startDetection();
      } else {
        _stopDetection();
      }
    }
  }

  @override
  void dispose() {
    _stopDetection();
    _textRecognizer.close();
    super.dispose();
  }

  void _startDetection() {
    if (widget.cameraController.value.isInitialized) {
      widget.cameraController.startImageStream(_processCameraImage);
    }
  }

  void _stopDetection() {
    _imageStreamSubscription?.cancel();
    if (widget.cameraController.value.isStreamingImages) {
      widget.cameraController.stopImageStream();
    }
    // Remove setState - just clear the values directly
    _targetBox = null;
    _animatedBox = null;
    _stableFrameCount = 0;
    _lastDetectedBox = null;
    _stabilityStartTime = null;
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || !widget.isEnabled) return;

    final now = DateTime.now();
    // Reduce from 300ms to ~33ms for 30fps processing (skip every other frame)
    // Use 16ms for true 60fps, but this may cause performance issues
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!).inMilliseconds < 200) {
      return;
    }

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation90deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final recognizedText = await _textRecognizer.processImage(inputImage);

      Rect? largestBox;
      int maxTextLength = 2;

      for (TextBlock block in recognizedText.blocks) {
        final scaledBox = _scaleRect(
          block.boundingBox,
          image.width.toDouble(),
          image.height.toDouble(),
        );

        if (_containsMathContent(block.text) &&
            block.text.length > maxTextLength) {
          maxTextLength = block.text.length;
          largestBox = scaledBox;
        }
      }

      if (!mounted) return;

      if (largestBox != null) {
        _stabilityStartTime ??= now;

        final stabilityDuration = now.difference(_stabilityStartTime!);
        if (stabilityDuration.inSeconds >= _stabilityTimeoutSeconds) {
          _stableFrameCount = 0;
          _lastDetectedBox = null;
          _stabilityStartTime = null;
          if (_targetBox != null || _animatedBox != null) {
            setState(() {
              _targetBox = null;
              _animatedBox = null;
            });
          }
        } else {
          bool shouldUpdateUI = false;

          if (_isBoxStable(largestBox)) {
            _stableFrameCount++;
          } else {
            _stableFrameCount = 0;
            _stabilityStartTime = now;
          }

          _lastDetectedBox = largestBox;

          if (_targetBox == null) {
            _targetBox = largestBox;
            _animatedBox = largestBox;
            shouldUpdateUI = true;
          } else {
            final distanceMoved =
                (_targetBox!.center - largestBox.center).distance;
            final sizeDiff = ((_targetBox!.width - largestBox.width).abs() +
                (_targetBox!.height - largestBox.height).abs()) /
                2;

            // Reduce threshold for smoother tracking at higher fps
            if (distanceMoved > 15 || sizeDiff > 10) {
              _targetBox = largestBox;
              shouldUpdateUI = true;
            }
          }

          if (shouldUpdateUI) {
            setState(() {});
          }

          if (_stableFrameCount >= _requiredStableFrames) {
            widget.onStableDetection(image, largestBox);
            _stableFrameCount = 0;
            _lastDetectedBox = null;
            _stabilityStartTime = null;
          }
        }
      } else {
        _stableFrameCount = 0;
        _lastDetectedBox = null;
        _stabilityStartTime = null;

        if (_targetBox != null || _animatedBox != null) {
          setState(() {
            _targetBox = null;
            _animatedBox = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error in auto detection: $e');
    } finally {
      _isProcessing = false;
    }
  }

  bool _isBoxStable(Rect newBox) {
    if (_lastDetectedBox == null) return false;

    final positionDiff = (newBox.center - _lastDetectedBox!.center).distance;
    final widthDiff = (newBox.width - _lastDetectedBox!.width).abs();
    final heightDiff = (newBox.height - _lastDetectedBox!.height).abs();

    return positionDiff < _stabilityThreshold &&
        widthDiff < _stabilityThreshold &&
        heightDiff < _stabilityThreshold;
  }

  Rect _scaleRect(Rect rect, double width, double height) {
    final size = MediaQuery.of(context).size;
    final bottomNavHeight = 280.0;
    final availableHeight = size.height - bottomNavHeight;

    final imageWidth = width;
    final imageHeight = height;
    final previewAspect = imageHeight / imageWidth;
    final containerAspect = size.width / availableHeight;

    double displayWidth, displayHeight;
    double offsetX = 0, offsetY = 0;

    if (previewAspect > containerAspect) {
      displayWidth = size.width;
      displayHeight = size.width / previewAspect;
      offsetY = (displayHeight - availableHeight) / 2;
    } else {
      displayHeight = availableHeight;
      displayWidth = availableHeight * previewAspect;
      offsetX = (displayWidth - size.width) / 2;
    }

    final scaleX = displayWidth / imageWidth;
    final scaleY = displayHeight / imageHeight;

    return Rect.fromLTRB(
      (rect.left * scaleX) - offsetX,
      (rect.top * scaleY) - offsetY,
      (rect.right * scaleX) - offsetX,
      (rect.bottom * scaleY) - offsetY,
    );
  }

  bool _containsMathContent(String text) {
    final cleanText = text.trim().toLowerCase();
    if (cleanText.length < 2) return false;

    final questionKeywords = RegExp(
      r'\b(find|solve|calculate|compute|determine|evaluate|simplify|prove|show|verify|'
      r'what|when|where|how|why|which|if|given|let|suppose|assume|consider|'
      r'express|write|graph|draw|sketch|plot|derive|obtain|state|'
      r'expand|factor|reduce|convert|transform|identify|explain|analyze|'
      r'compare|describe|illustrate|demonstrate|justify|classify|estimate)\b',
      caseSensitive: false,
    );

    final mathPattern = RegExp(
      r'(\d+\.?\d*\s*[+\-×÷*/=^]\s*\d+\.?\d*)|'
      r'([xyz]\s*[+\-×÷*/=^])|'
      r'(\d+[xyz])|'
      r'([xyz]\d+)|'
      r'(sqrt|sin|cos|tan|log|ln|lim|∫|∑|∞|π|α|β|γ)',
      caseSensitive: false,
    );

    final hasOperator = RegExp(r'[+\-×÷*/=^]').hasMatch(cleanText);
    final hasFraction = RegExp(r'\d+/\d+').hasMatch(cleanText);
    final hasEquation = RegExp(r'[a-z0-9]\s*=\s*[a-z0-9]', caseSensitive: false)
        .hasMatch(cleanText);
    final numberCount = RegExp(r'\d+').allMatches(cleanText).length;
    final hasUnits = RegExp(
        r'\d+\s*(cm|m|km|mm|kg|g|mg|l|ml|°|rad|°c|°f)',
        caseSensitive: false)
        .hasMatch(cleanText);

    return (questionKeywords.hasMatch(cleanText) &&
        (numberCount >= 1 || hasUnits)) ||
        mathPattern.hasMatch(cleanText) ||
        (hasOperator && numberCount >= 2) ||
        hasFraction ||
        hasEquation;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled || _targetBox == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBoxOverlay(
      targetBox: _targetBox!,
      currentBox: _animatedBox,
      onBoxUpdate: (box) {
        if (mounted) {
          setState(() {
            _animatedBox = box;
          });
        }
      },
      color: widget.color,
      pulseAnimation: widget.pulseAnimation,
    );
  }
}