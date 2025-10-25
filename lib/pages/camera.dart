import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/enums/capture_mode.dart';
import '../models/math_result.dart';
import '../providers/result_provider.dart';
import '../services/image_processor.dart';
import '../services/shape_detector.dart';
import '../theme/app_theme.dart';
import '../widgets/AnimatedBoxOverlay.dart';
import '../widgets/CustomPainter/CenterFramePainter.dart';
import '../widgets/draggable_resizable_box.dart';
import '../widgets/subject_selection_sheet.dart';
import 'dart:ui' as ui;
import '../services/ai_service.dart';
import '../models/math_result.dart';
import '../providers/result_provider.dart';
import 'dart:math' as math;
class CameraPage extends StatefulWidget {
  const CameraPage({super.key, this.onNavigateToTab});
  final Function(int)? onNavigateToTab;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _showSnapshot = false;
  Uint8List? _snapshotBytes;
  Rect? _snapshotBox;
  Timer? _detectionTimer;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  Rect? _targetBox;
  Rect? _animatedBox;
  bool _isProcessing = false;
  bool _isSheetVisible = false; // Add this flag
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  double? _originalImageWidth;
  double? _originalImageHeight;
  DateTime? _stabilityStartTime;
  static const int _stabilityTimeoutSeconds = 2;
  DateTime? _lastProcessTime;
  Rect? _lastDetectedBox;
  int _stableFrameCount = 0;
  static const int _requiredStableFrames = 3; // Number of stable frames needed
  static const double _stabilityThreshold = 10.0; // Pixels tolerance
  bool _showConfirmation = false;
  bool _isScanning = false;
  final double _centerFrameWidthRatio = 0.85; // 85% of screen width
  final double _centerFrameHeightRatio = 0.3; // 30% of screen height
  Rect? _centerFrame;
  bool _isFlashOn = false;
  List<DetectedShape> _detectedShapes = [];
  CaptureMode _captureMode = CaptureMode.automatic;
  bool isPressedCapture = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeCamera();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectionTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _pulseController.dispose();
    _textRecognizer.close();
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      _cameraController = null;
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController?.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      if (!_showSnapshot) {
        _cameraController?.startImageStream(_processCameraImage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_showSnapshot && _snapshotBytes != null && _snapshotBox != null)
            Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  _snapshotBytes!,
                  fit: BoxFit.cover,
                ),
                DraggableResizableBox(
                  initialBox: _snapshotBox!,
                  color: primaryColor,
                  isScanning: _isScanning,
                  onBoxChanged: (newBox) {
                    setState(() {
                      _snapshotBox = newBox;
                    });
                  },
                ),
              ],
            )
          else if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),

          if (!_showSnapshot && _targetBox != null && _captureMode == CaptureMode.automatic)
            AnimatedBoxOverlay(
              targetBox: _targetBox!,
              currentBox: _animatedBox,
              onBoxUpdate: (box) {
                setState(() {
                  _animatedBox = box;
                });
              },
              color: primaryColor,
              pulseAnimation: _pulseAnimation,
            ),
          if (!_showSnapshot && _centerFrame != null)
            Positioned.fill(
              child: CustomPaint(
                painter: CenterFramePainter(_centerFrame!, primaryColor),
              ),
            ),

          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: !_showConfirmation ? Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _flipCamera,
                        borderRadius: BorderRadius.circular(24),
                        child: const Center(
                          child: Icon(
                            Icons.flip_camera_ios_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Mode toggle button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final newMode = _captureMode == CaptureMode.automatic
                              ? CaptureMode.manual
                              : CaptureMode.automatic;

                          setState(() {
                            _captureMode = newMode;

                            // Clear annotations immediately when switching to manual mode
                            if (newMode == CaptureMode.manual) {
                              _targetBox = null;
                              _animatedBox = null;
                              _stableFrameCount = 0;
                              _lastDetectedBox = null;
                              _stabilityStartTime = null;
                              _detectionTimer?.cancel();
                              _detectionTimer = null;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _captureMode == CaptureMode.automatic
                                  ? Icons.auto_awesome
                                  : Icons.touch_app,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _captureMode == CaptureMode.automatic ? 'Auto' : 'Manual',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ) : const SizedBox.shrink(),
          ),


          // Bottom navigation (hide when snapshot is shown)
          if (!_showSnapshot)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 40, top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pickFromGallery,
                          borderRadius: BorderRadius.circular(32),
                          child: const Center(
                            child: Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        color: primaryColor,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _manualCapture,
                          borderRadius: BorderRadius.circular(40),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isFlashOn
                              ? Colors.amber.withOpacity(0.3)
                              : Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: _isFlashOn
                                ? Colors.amber
                                : Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleFlash,
                            borderRadius: BorderRadius.circular(28),
                            child: Center(
                              child: Icon(
                                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                                color: _isFlashOn ? Colors.amber : Colors.white,
                                size: 25,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_showSnapshot && _showConfirmation)
            Positioned(
              bottom: 70,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 40, top: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reset button
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _resetCapture,
                          borderRadius: BorderRadius.circular(32),
                          child: const Center(
                            child: Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Confirm button
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        color: primaryColor,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _confirmCapture,
                          borderRadius: BorderRadius.circular(40),
                          child: const Center(
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Placeholder for symmetry
                    const SizedBox(
                      width: 64,
                      height: 64,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isBoxStable(Rect newBox) {
    if (_lastDetectedBox == null) {
      return false;
    }

    // Check if position and size changes are within threshold
    final positionDiff = (newBox.center - _lastDetectedBox!.center).distance;
    final widthDiff = (newBox.width - _lastDetectedBox!.width).abs();
    final heightDiff = (newBox.height - _lastDetectedBox!.height).abs();

    return positionDiff < _stabilityThreshold &&
        widthDiff < _stabilityThreshold &&
        heightDiff < _stabilityThreshold;
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);

      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash not available on this device')),
      );
    }
  }

  Future<Uint8List> _cropImage(Uint8List imageBytes, Rect cropRect) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Convert screen coordinates to image coordinates
    final screenSize = MediaQuery.of(context).size;

    final scaleX = _originalImageWidth! / screenSize.width;
    final scaleY = _originalImageHeight! / screenSize.height;

    // Use the same padding as AnimatedBoxPainter
    const padding = 40.0;

    // Add padding to the crop rect
    final paddedRect = Rect.fromLTRB(
      (cropRect.left - padding).clamp(0, screenSize.width),
      (cropRect.top - padding).clamp(0, screenSize.height),
      (cropRect.right + padding).clamp(0, screenSize.width),
      (cropRect.bottom + padding).clamp(0, screenSize.height),
    );

    // Convert to image coordinates
    final cropRectInImage = Rect.fromLTRB(
      paddedRect.left * scaleX,
      paddedRect.top * scaleY,
      paddedRect.right * scaleX,
      paddedRect.bottom * scaleY,
    );

    // Clamp to image bounds
    final clampedRect = Rect.fromLTRB(
      cropRectInImage.left.clamp(0, image.width.toDouble()),
      cropRectInImage.top.clamp(0, image.height.toDouble()),
      cropRectInImage.right.clamp(0, image.width.toDouble()),
      cropRectInImage.bottom.clamp(0, image.height.toDouble()),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      image,
      clampedRect,
      Rect.fromLTWH(0, 0, clampedRect.width, clampedRect.height),
      Paint(),
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(
      clampedRect.width.toInt(),
      clampedRect.height.toInt(),
    );

    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _confirmCapture() async {
    if (_snapshotBytes == null || _snapshotBox == null) return;

    setState(() {
      _isSheetVisible = true;
    });

    try {
      final croppedImageBytes = await _cropImage(
        _snapshotBytes!,
        _snapshotBox!,
      );

      if (!mounted) return;

      final resultProvider = Provider.of<ResultProvider>(context, listen: false);
      final dbHelper = DatabaseHelper.instance;

      SubjectSelectionSheet.show(context, (subject) async {
        if (!mounted) return;

        final resultId = DateTime.now().millisecondsSinceEpoch.toString();

        final imagePath = await dbHelper.saveImageToStorage(
          base64Encode(croppedImageBytes),
          resultId,
        );

        final tempResult = MathResult(
          id: resultId,
          question: 'Preparing...',
          solution: 'Loading...',
          imagePath: imagePath,
          timestamp: DateTime.now(),
          subject: subject,
          answer: 'Please wait...',
        );

        resultProvider.setResultWithoutSaving(tempResult);
        widget.onNavigateToTab?.call(1);

        await ImageProcessor.processImageWithLazyLoading(
          base64Encode(croppedImageBytes),
          subject,
          resultProvider,
          resultId,
          imagePath,
        );

        _resetCamera();
      }).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _showConfirmation = true;
        });
      });
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
      _resetCamera();
    }
  }

  void _resetCapture() {
    _resetCamera();
  }

  Future<void> _flipCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other camera available')),
      );
      return;
    }

    try {
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();

      final currentCameraIndex = _cameras!.indexOf(_cameraController!.description);
      final newCameraIndex = (currentCameraIndex + 1) % _cameras!.length;

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,  // This disables shutter sound
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        _cameraController!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      debugPrint('Error flipping camera: $e');
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          _cameraController!.startImageStream(_processCameraImage);
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  bool _isBoxInCenterFrame(Rect box) {
    if (_centerFrame == null) return true;

    final boxCenter = box.center;
    return _centerFrame!.contains(boxCenter);
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isSheetVisible || _showSnapshot) return;

    final now = DateTime.now();
    if (_lastProcessTime != null && now.difference(_lastProcessTime!).inMilliseconds < 150) {
      return;
    }

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      final size = MediaQuery.of(context).size;

      final frameWidth = size.width * _centerFrameWidthRatio;
      final frameHeight = size.height * _centerFrameHeightRatio;
      final frameLeft = (size.width - frameWidth) / 2;
      final frameTop = (size.height - frameHeight) / 2;

      _centerFrame = Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight);

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
      int maxTextLength = 3;

      for (TextBlock block in recognizedText.blocks) {
        final scaledBox = _scaleRect(block.boundingBox, image.width.toDouble(), image.height.toDouble(),);

        if (_isBoxInCenterFrame(scaledBox) &&
            _containsMathContent(block.text) &&
            block.text.length > maxTextLength) {
          maxTextLength = block.text.length;
          largestBox = scaledBox;
        }
      }

      if (mounted && largestBox != null) {
        _stabilityStartTime ??= now;

        final stabilityDuration = now.difference(_stabilityStartTime!);
        if (stabilityDuration.inSeconds >= _stabilityTimeoutSeconds) {
          debugPrint('Stability timeout - resetting detection');
          _stableFrameCount = 0;
          _lastDetectedBox = null;
          _stabilityStartTime = null;
          setState(() {
            _targetBox = null;
            _animatedBox = null;
          });
        } else {
          if (_isBoxStable(largestBox)) {
            _stableFrameCount++;
            debugPrint('Stable frame: $_stableFrameCount/$_requiredStableFrames');
          } else {
            _stableFrameCount = 0;
            _stabilityStartTime = now;
          }

          _lastDetectedBox = largestBox;

          setState(() {
            _targetBox = largestBox;
            if (_animatedBox == null) {
              _animatedBox = largestBox;
            }
          });

          if (_stableFrameCount >= _requiredStableFrames) {
            _detectionTimer?.cancel();
            debugPrint('Box stable - capturing snapshot');
            if(_captureMode == CaptureMode.automatic || isPressedCapture){
              await _captureSnapshot(image, largestBox);
              _stableFrameCount = 0;
              _lastDetectedBox = null;
              _stabilityStartTime = null;
            }
          }
        }
      }
      else {
        if(isPressedCapture){
          Navigator.pop(context);
          isPressedCapture = false;
        }
        _stableFrameCount = 0;
        _lastDetectedBox = null;
        _stabilityStartTime = null;
        setState(() {
          _targetBox = null;
          _animatedBox = null;
        });
      }
    } catch (e) {
      debugPrint('Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }
  Future<void> _pickFromGallery() async {
    // Show loading dialog
    if (mounted) {
      _showLoadingDialog( message: 'Opening Gallery...');
    }
    try {
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController?.stopImageStream();
      }

      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedImage == null) {
        if (_cameraController != null &&
            _cameraController!.value.isInitialized &&
            !_cameraController!.value.isStreamingImages) {
          _cameraController?.startImageStream(_processCameraImage);
        }
        return;
      }



      final bytes = await pickedImage.readAsBytes();
      final inputImage = InputImage.fromFilePath(pickedImage.path);

      final recognizedText = await _textRecognizer.processImage(inputImage);

      Rect? largestBox;
      int maxTextLength = 3;

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final imageWidth = image.width.toDouble();
      final imageHeight = image.height.toDouble();

      for (TextBlock block in recognizedText.blocks) {
        final scaledBox = _scaleRect(block.boundingBox,imageWidth,imageHeight,);

        if (_isBoxInCenterFrame(scaledBox) &&
            _containsMathContent(block.text) &&
            block.text.length > maxTextLength) {
          maxTextLength = block.text.length;
          largestBox = scaledBox;
        }
      }

      final screenSize = MediaQuery.of(context).size;

      Rect displayBox;
      if (largestBox != null) {
        displayBox = largestBox;
      } else {
        final frameWidth = screenSize.width * _centerFrameWidthRatio;
        final frameHeight = screenSize.height * _centerFrameHeightRatio;
        displayBox = Rect.fromCenter(
          center: screenSize.center(Offset.zero),
          width: frameWidth,
          height: frameHeight,
        );
      }

      // Dismiss loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        setState(() {
          _snapshotBytes = bytes;
          _originalImageWidth = imageWidth;
          _originalImageHeight = imageHeight;
          _snapshotBox = displayBox;
          _showSnapshot = true;
          _isSheetVisible = false;
          _showConfirmation = true;
          _isScanning = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');

      // Dismiss loading dialog on error
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading image: $e')),
        );
      }

      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          !_cameraController!.value.isStreamingImages) {
        _cameraController?.startImageStream(_processCameraImage);
      }
    }
  }
  void _showLoadingDialog({String message =  'Loading image...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[850]
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureSnapshot(CameraImage image, Rect detectedBox) async {
    try {
      await _cameraController?.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 100));

      final XFile picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final capturedImage = frame.image;

      final capturedWidth = capturedImage.width.toDouble();
      final capturedHeight = capturedImage.height.toDouble();

      final previewSize = _cameraController!.value.previewSize!;
      final previewWidth = previewSize.height;
      final previewHeight = previewSize.width;

      final screenSize = MediaQuery.of(context).size;

      final previewAspect = previewWidth / previewHeight;
      final screenAspect = screenSize.width / screenSize.height;

      double displayWidth, displayHeight;
      if (previewAspect > screenAspect) {
        displayWidth = screenSize.width;
        displayHeight = screenSize.width / previewAspect;
      } else {
        displayHeight = screenSize.height;
        displayWidth = screenSize.height * previewAspect;
      }

      final offsetX = (screenSize.width - displayWidth) / 2;
      final offsetY = (screenSize.height - displayHeight) / 2;

      final normalizedBox = Rect.fromLTRB(
        (detectedBox.left - offsetX) / displayWidth,
        (detectedBox.top - offsetY) / displayHeight,
        (detectedBox.right - offsetX) / displayWidth,
        (detectedBox.bottom - offsetY) / displayHeight,
      );

      final scaledBox = Rect.fromLTRB(
        normalizedBox.left * capturedWidth,
        normalizedBox.top * capturedHeight,
        normalizedBox.right * capturedWidth,
        normalizedBox.bottom * capturedHeight,
      );

      final displayBox = Rect.fromLTRB(
        normalizedBox.left * screenSize.width,
        normalizedBox.top * screenSize.height,
        normalizedBox.right * screenSize.width,
        normalizedBox.bottom * screenSize.height,
      );

      setState(() {
        _snapshotBytes = bytes;
        _originalImageWidth = capturedWidth;
        _originalImageHeight = capturedHeight;
        _snapshotBox = displayBox;
        _showSnapshot = true;
        _isSheetVisible = false;
        _isScanning = false; // Set to false immediately
        _showConfirmation = true; // Show confirmation immediately
        if(isPressedCapture){
          Navigator.pop(context);
          isPressedCapture = false;
        }
      });
    } catch (e) {
      debugPrint('Error capturing snapshot: $e');
      _resetCamera();
    }
  }

  Future<void> _manualCapture() async {
    _showLoadingDialog(message: 'Scanning...');
    setState(() {
      isPressedCapture = true;
    });
  }



  void _resetCamera() {
    setState(() {
      _showSnapshot = false;
      _isSheetVisible = false;
      _targetBox = null;
      _animatedBox = null;
      _snapshotBytes = null;
      _snapshotBox = null;
      _isFlashOn = false;
      _stableFrameCount = 0;
      _lastDetectedBox = null;
      _stabilityStartTime = null;
      _showConfirmation = false;
      _detectedShapes = [];
    });
    _cameraController?.setFlashMode(FlashMode.off);
    _cameraController?.startImageStream(_processCameraImage);
  }

  Rect _scaleRect(Rect rect, double width, double height) {
    final size = MediaQuery.of(context).size;

    // Swap width/height due to rotation
    final imageWidth = width;
    final imageHeight = height;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  bool _containsMathContent(String text) {
    final mathPattern = RegExp(r'[\d+\-*/=()∫∑√^%x²³αβγπ]|[0-9]+|sin|cos|tan|log|ln|lim|∞');
    return mathPattern.hasMatch(text) && text.trim().length > 2;
  }

  void _navigateToProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to profile')),
    );
  }



}






