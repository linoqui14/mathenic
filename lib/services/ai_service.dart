import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/ai_analysis_result.dart';

class AIService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<AIAnalysisResult> analyzeImage(String base64Image, String subject) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );

    final prompt = _getPromptForSubject(subject);
    final imageBytes = base64Decode(base64Image);

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ])
    ];

    final response = await model.generateContent(content);
    final text = response.text ?? '';

    String question = 'No question found';
    String answer = 'No answer found';
    String solution = 'No solution found';

    // Extract question
    final questionMatch = RegExp(r'###QUESTION###\s*(.*?)\s*###END_QUESTION###', dotAll: true).firstMatch(text);
    if (questionMatch != null) {
      question = questionMatch.group(1)?.trim() ?? question;
    }

    // Extract answer
    final answerMatch = RegExp(r'###ANSWER###\s*(.*?)\s*###END_ANSWER###', dotAll: true).firstMatch(text);
    if (answerMatch != null) {
      answer = answerMatch.group(1)?.trim() ?? answer;
    }

    // Extract solution
    final solutionMatch = RegExp(r'###SOLUTION###\s*(.*?)\s*(?:###END_SOLUTION###|###ANSWER###|$)', dotAll: true).firstMatch(text);
    if (solutionMatch != null) {
      solution = solutionMatch.group(1)?.trim() ?? solution;
    }

    return AIAnalysisResult(
      question: question,
      solution: solution,
      answer: answer,
    );
  }

  String _getPromptForSubject(String subject) {
    final basePrompt = switch (subject.toLowerCase()) {
      'math' => 'Analyze this math problem and provide a detailed solution',
      'physics' => 'Analyze this physics problem and explain the concepts',
      'chemistry' => 'Analyze this chemistry problem and explain the reactions',
      'biology' => 'Analyze this biology problem and explain the concepts',
      _ => 'Analyze this academic problem and provide a solution',
    };

    return '''$basePrompt.
      You must structure your response EXACTLY as follows:

      ###QUESTION###
      Write the question clearly here.
      ###END_QUESTION###

      ###SOLUTION###
      Format your solution using Markdown with:
      - **Bold** for important terms
      - Numbered lists (1., 2., 3.) for steps
      - Bullet points (-) for key points
      - `code blocks` for equations
      - > for important notes

      Provide a step-by-step solution here.
      ###END_SOLUTION###

      ###ANSWER###
      Final answer here.
      ###END_ANSWER###

      Keep it clear and structured. Use the delimiters exactly as shown.''';
  }
}