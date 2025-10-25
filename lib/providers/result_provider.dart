import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/math_result.dart';
import '../database/database_helper.dart';

class ResultProvider extends ChangeNotifier {
  MathResult? _currentResult;
  List<MathResult> _historyResults = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  MathResult? get currentResult => _currentResult;
  List<MathResult> get historyResults => _historyResults;

  ResultProvider() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    _historyResults = await _dbHelper.getAllResults();
    notifyListeners();
  }

  // Add this method to result_provider.dart
  void setResultWithoutSaving(MathResult result) {
    _currentResult = result;
    notifyListeners();
  }

  Future<void> setResult(MathResult result) async {
    _currentResult = result;
    await _dbHelper.insertResult(result);
    await loadHistory();
    notifyListeners();
  }

  Future<String?> getImageBase64(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (e) {
      debugPrint('Error reading image: $e');
    }
    return null;
  }

  Future<void> deleteResult(String id) async {
    await _dbHelper.deleteResult(id);

    if (_currentResult?.id == id) {
      _currentResult = null;
    }

    await loadHistory();
    notifyListeners();
  }

  void clearResult() {
    _currentResult = null;
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    await _dbHelper.clearAllResults();
    _currentResult = null;
    _historyResults = [];
    notifyListeners();
  }
}