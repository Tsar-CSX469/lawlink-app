import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ConsumerQuizService {
  List<Map<String, dynamic>> questions = [];
  bool isLoading = true;
  String errorMessage = '';
  int currentQuestion = 0;
  bool answered = false;
  bool isCorrect = false;
  String explanation = '';
  int score = 0;
  int selectedAnswerIndex = -1;

  Future<void> loadQuizFromFirestore() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('quiz')
          .doc('consumer_affairs_quiz')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final questionsData = data['questions'] as List<dynamic>? ?? [];
        questions = questionsData.map((q) => _convertFirestoreQuestion(q)).toList();
        isLoading = false;
      } else {
        errorMessage = 'Quiz not found in database';
        isLoading = false;
      }
    } catch (e) {
      errorMessage = 'Error loading quiz: ${e.toString()}';
      isLoading = false;
    }
  }

  Map<String, dynamic> _convertFirestoreQuestion(Map<String, dynamic> firestoreQuestion) {
    final options = firestoreQuestion['options'] as List<dynamic>;
    final correctAnswerId = firestoreQuestion['correctAnswer'] as String;

    return {
      'question': firestoreQuestion['question'] as String,
      'answers': options.map((option) {
        final optionMap = option as Map<String, dynamic>;
        return {
          'text': optionMap['text'] as String,
          'correct': optionMap['id'] == correctAnswerId,
        };
      }).toList(),
      'explanation': firestoreQuestion['explanation'] as String,
      'points': firestoreQuestion['points'] as int? ?? 10,
      'category': firestoreQuestion['category'] as String? ?? '',
      'difficulty': firestoreQuestion['difficulty'] as String? ?? 'medium',
      'references': firestoreQuestion['references'] as List<dynamic>? ?? [],
    };
  }

  void answerQuestion(bool correct, String explanation, int points, int answerIndex) {
    answered = true;
    isCorrect = correct;
    this.explanation = explanation;
    selectedAnswerIndex = answerIndex;
    if (correct) {
      score += points;
    }
  }

  void nextQuestion() {
    currentQuestion++;
    answered = false;
    isCorrect = false;
    explanation = '';
    selectedAnswerIndex = -1;
  }

  Future<void> uploadScoreToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user is currently logged in.');
        return;
      }

      final scoreDoc = {
        'userId': user.uid,
        'quizId': 'consumer_affairs_quiz',
        'score': score,
        'total': getTotalPossibleScore(),
        'completedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('scores').add(scoreDoc);
      debugPrint('Score uploaded successfully.');
    } catch (e) {
      debugPrint('Failed to upload score: $e');
    }
  }

  void restartQuiz() {
    currentQuestion = 0;
    answered = false;
    isCorrect = false;
    explanation = '';
    score = 0;
    selectedAnswerIndex = -1;
  }

  int getTotalPossibleScore() {
    return questions.fold(0, (total, question) => total + (question['points'] as int));
  }

  List<Color> getDifficultyGradient(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return [Colors.green.shade400, Colors.green.shade600];
      case 'medium':
        return [Colors.orange.shade400, Colors.orange.shade600];
      case 'hard':
        return [Colors.red.shade400, Colors.red.shade600];
      default:
        return [Colors.blue.shade400, Colors.blue.shade600];
    }
  }

  Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green.shade500;
      case 'medium':
        return Colors.orange.shade500;
      case 'hard':
        return Colors.red.shade500;
      default:
        return Colors.blue.shade500;
    }
  }
}