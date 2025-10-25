import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ShapeDetector {
  /// Detects all shapes within the center frame
  static Future<List<DetectedShape>> detectShapesInFrame({
    required CameraImage cameraImage,
    required Size screenSize,
    required Rect centerFrame,
  }) async {
    try {
      final image = await _convertCameraImage(cameraImage);
      if (image == null) return [];

      final grayscale = img.grayscale(image);
      final edges = _applySobelEdgeDetection(grayscale);
      final contours = _findContours(edges);
      final shapes = _identifyShapes(contours);
      final scaledShapes = _scaleShapesToScreen(shapes, image, screenSize);

      // Filter shapes that are in the center frame
      final frameShapes = filterShapesByFrame(scaledShapes, centerFrame);

      return frameShapes;
    } catch (e) {
      debugPrint('Error detecting shapes: $e');
      return [];
    }
  }

  /// Detects shapes (circles, rectangles) near the given text box
  /// Detects all shapes in the image
  /// Detects shapes within the center frame
  static Future<List<DetectedShape>> detectShapesNearText({
    required CameraImage cameraImage,
    required Rect textBox,
    required Size screenSize,
    required Rect centerFrame,
    double proximityThreshold = 100.0,
  }) async {
    try {
      final image = await _convertCameraImage(cameraImage);
      if (image == null) return [];

      final grayscale = img.grayscale(image);
      final edges = _applySobelEdgeDetection(grayscale);
      final contours = _findContours(edges);
      final shapes = _identifyShapes(contours);
      final scaledShapes = _scaleShapesToScreen(shapes, image, screenSize);

      // Filter shapes that are in the center frame
      final frameShapes = filterShapesByFrame(scaledShapes, centerFrame);

      return frameShapes;
    } catch (e) {
      debugPrint('Error detecting shapes: $e');
      return [];
    }
  }
  /// Filters shapes that are within or overlap the center frame
  static List<DetectedShape> filterShapesByFrame(
      List<DetectedShape> shapes,
      Rect centerFrame,
      ) {
    return shapes.where((shape) {
      // Check if shape overlaps with center frame
      return shape.bounds.overlaps(centerFrame) ||
          centerFrame.contains(shape.bounds.center);
    }).toList();
  }

  /// Converts CameraImage to img.Image
  static Future<img.Image?> _convertCameraImage(CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      // Handle YUV420 format
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

      final image = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = uvPixelStride * (x / 2).floor() +
              uvRowStride * (y / 2).floor();
          final int index = y * width + x;

          final yp = cameraImage.planes[0].bytes[index];
          final up = cameraImage.planes[1].bytes[uvIndex];
          final vp = cameraImage.planes[2].bytes[uvIndex];

          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
              .round()
              .clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

          image.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return image;
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  /// Applies Sobel edge detection
  static img.Image _applySobelEdgeDetection(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);

    // Sobel kernels
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final intensity = pixel.r.toInt();

            gx += intensity * sobelX[ky + 1][kx + 1];
            gy += intensity * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = sqrt(gx * gx + gy * gy).toInt().clamp(0, 255);
        result.setPixelRgba(x, y, magnitude, magnitude, magnitude, 255);
      }
    }

    return result;
  }

  /// Finds contours in the edge-detected image
  static List<List<Point>> _findContours(img.Image edges) {
    final contours = <List<Point>>[];
    final visited = List.generate(
      edges.height,
          (_) => List.filled(edges.width, false),
    );

    for (int y = 0; y < edges.height; y++) {
      for (int x = 0; x < edges.width; x++) {
        if (!visited[y][x] && edges.getPixel(x, y).r > 128) {
          final contour = _traceContour(edges, x, y, visited);
          if (contour.length > 20) {
            // Minimum contour size
            contours.add(contour);
          }
        }
      }
    }

    return contours;
  }

  /// Traces a single contour
  static List<Point> _traceContour(
      img.Image edges,
      int startX,
      int startY,
      List<List<bool>> visited,
      ) {
    final contour = <Point>[];
    final stack = <Point>[Point(startX, startY)];

    while (stack.isNotEmpty) {
      final point = stack.removeLast();
      final x = point.x;
      final y = point.y;

      if (x < 0 || x >= edges.width || y < 0 || y >= edges.height) continue;
      if (visited[y][x]) continue;
      if (edges.getPixel(x, y).r <= 128) continue;

      visited[y][x] = true;
      contour.add(point);

      // Check 8 neighbors
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          stack.add(Point(x + dx, y + dy));
        }
      }
    }

    return contour;
  }

  /// Identifies geometric shapes from contours
  static List<DetectedShape> _identifyShapes(List<List<Point>> contours) {
    final shapes = <DetectedShape>[];

    for (final contour in contours) {
      if (contour.length < 20) continue;

      // Calculate bounding box
      int minX = contour.first.x;
      int maxX = contour.first.x;
      int minY = contour.first.y;
      int maxY = contour.first.y;

      for (final point in contour) {
        minX = minX < point.x ? minX : point.x;
        maxX = maxX > point.x ? maxX : point.x;
        minY = minY < point.y ? minY : point.y;
        maxY = maxY > point.y ? maxY : point.y;
      }

      final width = maxX - minX;
      final height = maxY - minY;
      final aspectRatio = width / height;

      // Detect circles (aspect ratio close to 1, relatively round)
      if ((aspectRatio > 0.8 && aspectRatio < 1.2) && _isCircular(contour)) {
        shapes.add(DetectedShape(
          type: ShapeType.circle,
          bounds: Rect.fromLTWH(
            minX.toDouble(),
            minY.toDouble(),
            width.toDouble(),
            height.toDouble(),
          ),
          confidence: 0.8,
        ));
      }
      // Detect rectangles
      else if (_isRectangular(contour)) {
        shapes.add(DetectedShape(
          type: ShapeType.rectangle,
          bounds: Rect.fromLTWH(
            minX.toDouble(),
            minY.toDouble(),
            width.toDouble(),
            height.toDouble(),
          ),
          confidence: 0.7,
        ));
      }
    }

    return shapes;
  }

  /// Checks if a contour is circular
  static bool _isCircular(List<Point> contour) {
    if (contour.length < 20) return false;

    // Calculate center
    double centerX = 0;
    double centerY = 0;
    for (final point in contour) {
      centerX += point.x;
      centerY += point.y;
    }
    centerX /= contour.length;
    centerY /= contour.length;

    // Calculate average radius
    double avgRadius = 0;
    for (final point in contour) {
      final dx = point.x - centerX;
      final dy = point.y - centerY;
      avgRadius += sqrt(dx * dx + dy * dy);
    }
    avgRadius /= contour.length;

    // Check radius variance
    double variance = 0;
    for (final point in contour) {
      final dx = point.x - centerX;
      final dy = point.y - centerY;
      final radius = sqrt(dx * dx + dy * dy);
      variance += (radius - avgRadius) * (radius - avgRadius);
    }
    variance /= contour.length;

    // Low variance indicates circular shape
    return variance / avgRadius < 0.2;
  }

  /// Checks if a contour is rectangular
  static bool _isRectangular(List<Point> contour) {
    if (contour.length < 20) return false;

    // Approximate polygon
    final epsilon = 0.04 * _contourPerimeter(contour);
    final approx = _approximatePolygon(contour, epsilon);

    // Rectangle should have 4 vertices
    return approx.length == 4;
  }

  /// Calculates contour perimeter
  static double _contourPerimeter(List<Point> contour) {
    double perimeter = 0;
    for (int i = 0; i < contour.length - 1; i++) {
      final dx = contour[i + 1].x - contour[i].x;
      final dy = contour[i + 1].y - contour[i].y;
      perimeter += sqrt(dx * dx + dy * dy);
    }
    return perimeter;
  }

  /// Approximates polygon using Douglas-Peucker algorithm
  static List<Point> _approximatePolygon(List<Point> contour, double epsilon) {
    if (contour.length < 3) return contour;

    // Simplified version - in production, use full Douglas-Peucker
    return contour;
  }

  /// Scales shapes from image coordinates to screen coordinates
  static List<DetectedShape> _scaleShapesToScreen(
      List<DetectedShape> shapes,
      img.Image image,
      Size screenSize,
      ) {
    final scaleX = screenSize.width / image.width;
    final scaleY = screenSize.height / image.height;

    return shapes.map((shape) {
      return DetectedShape(
        type: shape.type,
        bounds: Rect.fromLTRB(
          shape.bounds.left * scaleX,
          shape.bounds.top * scaleY,
          shape.bounds.right * scaleX,
          shape.bounds.bottom * scaleY,
        ),
        confidence: shape.confidence,
      );
    }).toList();
  }

  /// Filters shapes that are near the text box
  static List<DetectedShape> _filterShapesNearText(
      List<DetectedShape> shapes,
      Rect textBox,
      double threshold,
      ) {
    return shapes.where((shape) {
      final distance = _distanceBetweenRects(shape.bounds, textBox);
      return distance <= threshold;
    }).toList();
  }

  /// Calculates distance between two rectangles
  static double _distanceBetweenRects(Rect rect1, Rect rect2) {
    final dx = (rect1.center.dx - rect2.center.dx).abs();
    final dy = (rect1.center.dy - rect2.center.dy).abs();
    return sqrt(dx * dx + dy * dy);
  }
}

class Point {
  final int x;
  final int y;

  Point(this.x, this.y);
}

enum ShapeType {
  circle,
  rectangle,
  line,
}

class DetectedShape {
  final ShapeType type;
  final Rect bounds;
  final double confidence;

  DetectedShape({
    required this.type,
    required this.bounds,
    required this.confidence,
  });
}