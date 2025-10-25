import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';
import '../models/math_result.dart';
import '../providers/result_provider.dart';
import '../database/database_helper.dart';

class ImageProcessor {
  static Future<void> processImageWithLazyLoading(
      String base64Image,
      String subject,
      ResultProvider provider,
      String resultId,
      String imagePath,
      ) async {
    try {
      final aiService = AIService();

      // Show loading state
      final loadingResult = MathResult(
        id: resultId,
        question: 'Analyzing question...',
        solution: 'Generating solution...',
        answer: 'Calculating answer...',
        imagePath: imagePath,
        timestamp: DateTime.now(),
        subject: subject,
      );
      provider.setResultWithoutSaving(loadingResult);

      // Wait a bit for UI to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Get AI response
      final aiResult = await aiService.analyzeImage(base64Image, subject);

      // Update with question first
      final questionResult = MathResult(
        id: resultId,
        question: aiResult.question,
        solution: 'Generating solution...',
        answer: 'Calculating answer...',
        imagePath: imagePath,
        timestamp: DateTime.now(),
        subject: subject,
      );
      provider.setResultWithoutSaving(questionResult);
      await Future.delayed(const Duration(milliseconds: 300));

      // Update with solution
      final solutionResult = MathResult(
        id: resultId,
        question: aiResult.question,
        solution: aiResult.solution,
        answer: 'Calculating answer...',
        imagePath: imagePath,
        timestamp: DateTime.now(),
        subject: subject,
      );
      provider.setResultWithoutSaving(solutionResult);
      await Future.delayed(const Duration(milliseconds: 300));

      // Final result with answer and save to database
      final finalResult = MathResult(
        id: resultId,
        question: aiResult.question,
        solution: aiResult.solution,
        answer: aiResult.answer,
        imagePath: imagePath,
        timestamp: DateTime.now(),
        subject: subject,
      );

      await provider.setResult(finalResult);
      debugPrint('✅ Result saved to history after completion');

    } catch (e) {
      debugPrint('❌ Error processing image: $e');

      final errorResult = MathResult(
        id: resultId,
        question: 'Error analyzing image',
        solution: 'Please try again',
        answer: 'N/A',
        imagePath: imagePath,
        timestamp: DateTime.now(),
        subject: subject,
      );
      provider.setResultWithoutSaving(errorResult);
    }
  }
}