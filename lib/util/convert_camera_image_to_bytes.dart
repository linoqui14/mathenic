import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:image/image.dart' as img;

// Add this helper method to convert CameraImage to Image
Future<Uint8List> convertCameraImageToBytes(CameraImage cameraImage) async {
  try {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    // Create an Image object
    final img.Image image = img.Image(width: width, height: height);

    // Convert YUV420 to RGB
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yValue = cameraImage.planes[0].bytes[index];
        final uValue = cameraImage.planes[1].bytes[uvIndex];
        final vValue = cameraImage.planes[2].bytes[uvIndex];

        // YUV to RGB conversion
        final int r = (yValue + vValue * 1436 / 1024 - 179).round().clamp(0, 255);
        final int g = (yValue - uValue * 46549 / 131072 + 44 - vValue * 93604 / 131072 + 91).round().clamp(0, 255);
        final int b = (yValue + uValue * 1814 / 1024 - 227).round().clamp(0, 255);

        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    // Rotate 90 degrees clockwise to match camera orientation
    final img.Image rotated = img.copyRotate(image, angle: 90);

    // Encode to PNG
    final List<int> png = img.encodePng(rotated);
    return Uint8List.fromList(png);
  } catch (e) {
    debugPrint('Error converting camera image: $e');
    rethrow;
  }
}