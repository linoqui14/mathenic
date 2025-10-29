import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/enums/capture_mode.dart';
import '../models/math_result.dart';
import '../providers/result_provider.dart';
import '../services/image_processor.dart';
import '../theme/app_theme.dart';
import '../widgets/CustomPainter/center_frame_painter.dart';
import '../widgets/animated_box_overlay.dart';
import '../widgets/auto_detection_overlay.dart';
import '../widgets/draggable_resizable_box.dart';
import '../widgets/snapshot_editor.dart';
import '../widgets/subject_selection_sheet.dart';
import 'dart:ui' as ui;
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
  bool isMenuVisible = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isSheetVisible = false; // Add this flag
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  double? _originalImageWidth;
  double? _originalImageHeight;
  static const int _stabilityTimeoutSeconds = 2;
  static const int _requiredStableFrames = 3; // Number of stable frames needed
  static const double _stabilityThreshold = 20.0; // Pixels tolerance
  bool _isScanning = false;
  final double _centerFrameWidthRatio = 0.85; // 85% of screen width
  final double _centerFrameHeightRatio = 0.3; // 30% of screen height
  Rect? _centerFrame;
  bool _isFlashOn = false;
  FlashMode _flashMode = FlashMode.off;

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

    // Initialize center frame after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _centerFrame = Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width * _centerFrameWidthRatio,
          height: size.height * _centerFrameHeightRatio,
        );
      });
    });
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
        // _cameraController?.startImageStream(_processCameraImage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(!_showSnapshot && _captureMode == CaptureMode.automatic && _cameraController != null);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(30)),
                child: Stack(
                  children: [
                    if (_showSnapshot && _snapshotBytes != null && _snapshotBox != null)
                      SnapshotEditor(
                        isMenuVisible: isMenuVisible,
                        imageBytes: _snapshotBytes!,
                        initialBox: _snapshotBox!,
                        color: primaryColor,
                        isScanning: _isScanning,
                        onBoxChanged: (newBox) {
                          print("Box Updated: $newBox");
                          setState(() {
                            _snapshotBox = newBox;
                          });
                        },
                        onStable: (box) {
                          _confirmCapture();
                        },
                      )
                    else if (_isCameraInitialized && _cameraController != null)
                      SizedBox.expand(
                        child: OverflowBox(
                          maxHeight:MediaQuery.of(context).size.height-150,
                          alignment: Alignment.center,
                          fit: OverflowBoxFit.max,
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    else
                      Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
                    if (!_showSnapshot && _captureMode == CaptureMode.automatic && _cameraController != null)
                      AutoDetectionOverlay(
                        cameraController: _cameraController!,
                        pulseAnimation: _pulseAnimation,
                        color: primaryColor,
                        isEnabled: true,
                        onStableDetection: (image, box) async {
                          if (isPressedCapture) {
                            await _captureSnapshot(image, box);
                          }
                        },
                      ),
                    if (!_showSnapshot || _snapshotBytes == null && _snapshotBox != null)
                      Container(
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
                                  child: FaIcon(
                                    FontAwesomeIcons.arrowRotateLeft,
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
                    ),
                    if(!_showSnapshot && _snapshotBytes == null && _snapshotBox == null)
                    Positioned(
                      bottom: 10,
                      left: MediaQuery.of(context).size.width / 2 - 20,

                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _flashMode != FlashMode.off
                                ? Colors.amber.withOpacity(0.3)
                                : Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: _flashMode != FlashMode.off
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
                                child: FaIcon(
                                  _flashMode == FlashMode.torch
                                      ? Icons.flash_on
                                      : _flashMode == FlashMode.auto
                                      ? Icons.flash_auto
                                      : Icons.flash_off,
                                  color: _flashMode != FlashMode.off ? Colors.amber : Colors.white,
                                  size: 20,
                                ),
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
            Container(
              padding: const EdgeInsets.only(bottom: 40, top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!_showSnapshot && _snapshotBytes == null && _snapshotBox == null)
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
                          child: FaIcon(
                            FontAwesomeIcons.image,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          if(!_showSnapshot && _snapshotBytes == null && _snapshotBox == null){
                            _manualCapture();
                            return;
                          }
                          await _initializeCamera();
                          _resetCapture();
                        },
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purple,
                          ),
                          child: (_showSnapshot && _snapshotBytes != null && _snapshotBox != null) ? Center(
                            child: FaIcon(
                              FontAwesomeIcons.arrowRotateRight,
                              color: Colors.white,
                              size: 30,
                            ),
                          ) : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                  if (!_showSnapshot && _snapshotBytes == null && _snapshotBox == null)
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
                          child: FaIcon(
                            FontAwesomeIcons.microphoneLines,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Cycle through: off → on → auto
      FlashMode newMode;
      if (_flashMode == FlashMode.off) {
        newMode = FlashMode.torch;
      } else if (_flashMode == FlashMode.torch) {
        newMode = FlashMode.auto;
      } else {
        newMode = FlashMode.off;
      }

      await _cameraController!.setFlashMode(newMode);

      setState(() {
        _flashMode = newMode;
        _isFlashOn = newMode != FlashMode.off;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
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
      isMenuVisible = true;
    });

    try {
      final croppedImageBytes = await _cropImage(
        _snapshotBytes!,
        _snapshotBox!,
      );

      if (!mounted) return;

      final resultProvider = Provider.of<ResultProvider>(context, listen: false);
      final dbHelper = DatabaseHelper.instance;

      await SubjectSelectionSheet.show(context, (subject) async {
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
        widget.onNavigateToTab?.call(0);

        await ImageProcessor.processImageWithLazyLoading(
          base64Encode(croppedImageBytes),
          subject,
          resultProvider,
          resultId,
          imagePath,
        );

        _resetCamera();
      },(){
        setState(() {
          isMenuVisible = false;
        });
      }).whenComplete(() {
        if (!mounted) return;
      });
      setState(() {
        isMenuVisible = false;
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
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Stop image stream BEFORE disposing
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await Future.delayed(Duration(milliseconds: 80));
      // Cancel detection timer
      _detectionTimer?.cancel();
      _detectionTimer = null;

      // Get the next camera
      final cameras = await availableCameras();
      final currentIndex = cameras.indexWhere((camera) =>
      camera.lensDirection == _cameraController!.description.lensDirection
      );

      final nextCamera = cameras[currentIndex == 0 ? 1 : 0];

      // Dispose current controller
      await _cameraController!.dispose();
      _cameraController = null;

      // Reset state
      setState(() {
        _isCameraInitialized = false;
      });

      // Initialize new camera
      await _initializeCamera();
    } catch (e) {
      if (mounted) {
        debugPrint('Error flipping camera: $e');
      }
    }
  }

  Future<void> _initializeCamera([CameraDescription? camera]) async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Use provided camera or default to first one
        final selectedCamera = camera ?? _cameras![0];

        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
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
          // _cameraController?.startImageStream(_processCameraImage);
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
        // _cameraController?.startImageStream(_processCameraImage);
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
      final bottomOffset = 280.0; // Match _scaleRect value
      final availableHeight = screenSize.height - bottomOffset;

      final previewAspect = previewWidth / previewHeight;
      final containerAspect = screenSize.width / availableHeight;

      double displayWidth, displayHeight;
      double offsetX = 0, offsetY = 0;

      if (previewAspect > containerAspect) {
        displayWidth = screenSize.width;
        displayHeight = screenSize.width / previewAspect;
        offsetY = (displayHeight - availableHeight) / 2;
      } else {
        displayHeight = availableHeight;
        displayWidth = availableHeight * previewAspect;
        offsetX = (displayWidth - screenSize.width) / 2;
      }

      final normalizedBox = Rect.fromLTRB(
        (detectedBox.left + offsetX) / displayWidth,
        (detectedBox.top + offsetY) / displayHeight,
        (detectedBox.right + offsetX) / displayWidth,
        (detectedBox.bottom + offsetY) / displayHeight,
      );

      final displayBox = Rect.fromLTRB(
        (normalizedBox.left * displayWidth) - offsetX,
        (normalizedBox.top * displayHeight) - offsetY,
        (normalizedBox.right * displayWidth) - offsetX,
        (normalizedBox.bottom * displayHeight) - offsetY,
      );

      setState(() {
        _snapshotBytes = bytes;
        _originalImageWidth = capturedWidth;
        _originalImageHeight = capturedHeight;
        _snapshotBox = displayBox;
        _showSnapshot = true;
        _isSheetVisible = false;
        _isScanning = false;
        _cameraController?.dispose();
        _confirmCapture();
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
    _showLoadingDialog(message: 'Please stay still while scanning...');
    setState(() {
      isPressedCapture = true;
    });
  }

  void _resetCamera() {
    setState(() {
      _showSnapshot = false;
      _isSheetVisible = false;
      _snapshotBytes = null;
      _snapshotBox = null;
      _flashMode = FlashMode.off;
      _isFlashOn = false;
    });
    _cameraController?.setFlashMode(FlashMode.off);
    // _cameraController?.startImageStream(_processCameraImage);
  }

  Rect _scaleRect(Rect rect, double width, double height) {
    final size = MediaQuery.of(context).size;

    // Account for bottom navigation bar (65px height from NavigationBar)
    final bottomNavHeight = 280.0;
    final availableHeight = size.height - bottomNavHeight;

    // Camera preview dimensions (swapped due to rotation)
    final imageWidth = width;
    final imageHeight = height;

    // Calculate preview aspect ratio
    final previewAspect = imageHeight / imageWidth;

    // Calculate container aspect ratio using available height
    final containerAspect = size.width / availableHeight;

    double displayWidth, displayHeight;
    double offsetX = 0, offsetY = 0;

    if (previewAspect > containerAspect) {
      // Preview is taller - width matches container, height overflows
      displayWidth = size.width;
      displayHeight = size.width / previewAspect;
      offsetY = (displayHeight - availableHeight) / 2;
    } else {
      // Preview is wider - height matches container, width overflows
      displayHeight = availableHeight;
      displayWidth = availableHeight * previewAspect;
      offsetX = (displayWidth - size.width) / 2;
    }

    // Calculate scaling factors
    final scaleX = displayWidth / imageWidth;
    final scaleY = displayHeight / imageHeight;

    // Scale and adjust for any overflow offset
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

    // Question keywords that indicate a problem or task
    final questionKeywords = RegExp(
      r'\b(find|solve|calculate|compute|determine|evaluate|simplify|prove|show|verify|'
      r'what|when|where|how|why|which|if|given|let|suppose|assume|consider|'
      r'express|write|graph|draw|sketch|plot|derive|obtain|state|'
      r'expand|factor|reduce|convert|transform|identify|explain|analyze|'
      r'compare|describe|illustrate|demonstrate|justify|classify|estimate)\b',
      caseSensitive: false,
    );

    // Mathematical expressions
    final mathPattern = RegExp(
      r'(\d+\.?\d*\s*[+\-×÷*/=^]\s*\d+\.?\d*)|'  // Operations with numbers
      r'([xyz]\s*[+\-×÷*/=^])|'                    // Variables with operators
      r'(\d+[xyz])|'                               // Coefficients (2x, 3y)
      r'([xyz]\d+)|'                               // Variable with exponent
      r'(sqrt|sin|cos|tan|log|ln|lim|∫|∑|∞|π|α|β|γ)',  // Functions and symbols
      caseSensitive: false,
    );

    // Additional math indicators
    final hasOperator = RegExp(r'[+\-×÷*/=^]').hasMatch(cleanText);
    final hasFraction = RegExp(r'\d+/\d+').hasMatch(cleanText);
    final hasEquation = RegExp(r'[a-z0-9]\s*=\s*[a-z0-9]', caseSensitive: false).hasMatch(cleanText);
    final numberCount = RegExp(r'\d+').allMatches(cleanText).length;

    // Check for units (cm, m, kg, etc.)
    final hasUnits = RegExp(r'\d+\s*(cm|m|km|mm|kg|g|mg|l|ml|°|rad|°c|°f)', caseSensitive: false).hasMatch(cleanText);

    // Return true if text contains:
    // 1. Question keywords + numbers OR
    // 2. Math patterns OR
    // 3. Operators with sufficient numbers OR
    // 4. Fractions/equations OR
    // 5. Question keywords + units
    return (questionKeywords.hasMatch(cleanText) && (numberCount >= 1 || hasUnits)) ||
        mathPattern.hasMatch(cleanText) ||
        (hasOperator && numberCount >= 2) ||
        hasFraction ||
        hasEquation;
  }

}






