import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class QuizApiService {
  // Update this URL to match your Firebase Functions deployment
  // Production URL - Firebase Functions (Updated after redeployment)
  static const String baseUrl = 'https://quizlawlink-kwcxt5yrbq-uc.a.run.app';

  // Local development/testing - Firebase Emulator
  // static const String baseUrl =
  //     'http://127.0.0.1:5001/demo-test/us-central1/quizLawLink';

  // Get authorization headers
  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    String? token;

    if (user != null) {
      token = await user.getIdToken();
    }

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get all available quizzes
  static Future<List<Map<String, dynamic>>> getAvailableQuizzes({
    String? category,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse(
        '$baseUrl/quizzes${category != null ? '?category=$category' : ''}',
      );

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']['quizzes']);
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch quizzes');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to fetch quizzes');
      }
    } catch (e) {
      print('Error fetching quizzes: $e');
      rethrow;
    }
  }

  /// Get a specific quiz with questions
  static Future<Map<String, dynamic>> getQuiz(
    String quizId, {
    bool includeAnswers = false,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse(
        '$baseUrl/quiz/$quizId${includeAnswers ? '?includeAnswers=true' : ''}',
      );

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['quiz'];
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch quiz');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to fetch quiz');
      }
    } catch (e) {
      print('Error fetching quiz: $e');
      rethrow;
    }
  }

  /// Submit quiz answers
  static Future<Map<String, dynamic>> submitQuiz({
    required String quizId,
    required String userId,
    required List<Map<String, dynamic>> answers,
    required int duration,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/quiz/$quizId/submit');

      final body = json.encode({
        'userId': userId,
        'answers': answers,
        'duration': duration,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['result'];
        } else {
          throw Exception(data['error'] ?? 'Failed to submit quiz');
        }
      } else {
        // Parse error response for better error messages
        String errorMessage = 'Failed to submit quiz';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) {
            errorMessage = errorData['error'];
          }
        } catch (e) {
          // Use default message if parsing fails
        }

        // Special handling for time-related errors
        if (response.statusCode == 400 && errorMessage.contains('too fast')) {
          throw Exception(
            '⏱️ Please take more time to complete the quiz. You cannot submit too quickly to ensure fair assessment.',
          );
        } else if (response.statusCode == 400 &&
            errorMessage.contains('time limit exceeded')) {
          throw Exception(
            '⏰ Quiz time limit exceeded. Please complete the quiz within the allowed time.',
          );
        } else {
          throw Exception('HTTP ${response.statusCode}: $errorMessage');
        }
      }
    } catch (e) {
      print('Error submitting quiz: $e');
      rethrow;
    }
  }

  /// Validate a single answer in real-time
  static Future<Map<String, dynamic>> validateAnswer({
    required String quizId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/quiz/$quizId/validate-answer');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'questionId': questionId,
          'selectedOptionId': selectedOptionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'Failed to validate answer');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: Failed to validate answer',
        );
      }
    } catch (e) {
      print('Error validating answer: $e');
      rethrow;
    }
  }

  /// Get user's quiz history
  static Future<List<Map<String, dynamic>>> getUserQuizHistory(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/user/$userId/history?limit=$limit');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']['history']);
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch quiz history');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: Failed to fetch quiz history',
        );
      }
    } catch (e) {
      print('Error fetching quiz history: $e');
      rethrow;
    }
  }

  /// Get leaderboard
  static Future<List<Map<String, dynamic>>> getLeaderboard({
    String? quizId,
    int limit = 50,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (quizId != null) 'quizId': quizId,
      };

      final url = Uri.parse(
        '$baseUrl/leaderboard',
      ).replace(queryParameters: queryParams);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']['leaderboard']);
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch leaderboard');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: Failed to fetch leaderboard',
        );
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
      rethrow;
    }
  }

  /// Get quiz statistics
  static Future<Map<String, dynamic>> getQuizStats(String quizId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/quiz/$quizId/stats');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['stats'];
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch quiz stats');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: Failed to fetch quiz stats',
        );
      }
    } catch (e) {
      print('Error fetching quiz stats: $e');
      rethrow;
    }
  }
}

/// Model classes for better type safety

class QuizAnswer {
  final String questionId;
  final String selectedOptionId;
  final int timeSpent;

  QuizAnswer({
    required this.questionId,
    required this.selectedOptionId,
    required this.timeSpent,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedOptionId': selectedOptionId,
    'timeSpent': timeSpent,
  };
}

class QuizResult {
  final int score;
  final int totalPoints;
  final int percentage;
  final bool passed;
  final List<QuizAnswerResult> answers;

  QuizResult({
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.passed,
    required this.answers,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      score: json['score'],
      totalPoints: json['totalPoints'],
      percentage: json['percentage'],
      passed: json['passed'],
      answers:
          (json['answers'] as List)
              .map((a) => QuizAnswerResult.fromJson(a))
              .toList(),
    );
  }
}

class QuizAnswerResult {
  final String questionId;
  final String selectedOptionId;
  final String correctOptionId;
  final bool isCorrect;
  final String explanation;
  final int points;

  QuizAnswerResult({
    required this.questionId,
    required this.selectedOptionId,
    required this.correctOptionId,
    required this.isCorrect,
    required this.explanation,
    required this.points,
  });

  factory QuizAnswerResult.fromJson(Map<String, dynamic> json) {
    return QuizAnswerResult(
      questionId: json['questionId'],
      selectedOptionId: json['selectedOptionId'],
      correctOptionId: json['correctOptionId'],
      isCorrect: json['isCorrect'],
      explanation: json['explanation'],
      points: json['points'],
    );
  }
}
