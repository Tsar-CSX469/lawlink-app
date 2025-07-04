import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ConsumerQuizService {
  // Existing properties
  List<Map<String, dynamic>> questions = [];
  bool isLoading = true;
  String errorMessage = '';
  int currentQuestion = 0;
  bool answered = false;
  bool isCorrect = false;
  String explanation = '';
  int score = 0;
  int selectedAnswerIndex = -1;

  // Lives system properties
  int _currentLives = 5;
  int _maxLives = 5;
  bool _isLifeAnimating = false;
  bool _gameOver = false;
  String? _currentGameSessionId;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Getters for lives
  int get currentLives => _currentLives;
  int get maxLives => _maxLives;
  bool get isLifeAnimating => _isLifeAnimating;
  bool get gameOver => _gameOver;
  String? get currentGameSessionId => _currentGameSessionId;

  // Existing methods remain the same
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

  // NEW LIVES SYSTEM METHODS

  // Load user's current lives from Firebase
  Future<void> loadUserLives() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data();
          final gameStats = userData?['gameStats'] as Map<String, dynamic>?;
          
          if (gameStats != null) {
            final lives = gameStats['lives'] as Map<String, dynamic>?;
            if (lives != null) {
              _currentLives = lives['current'] ?? 5;
              _maxLives = lives['maxDaily'] ?? 5;
              
              // Check if lives need regeneration
              await _checkLifeRegeneration(lives);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user lives: $e');
      // Fallback to default values
      _currentLives = 5;
      _maxLives = 5;
    }
  }

  // Check and regenerate lives if needed
  Future<void> _checkLifeRegeneration(Map<String, dynamic> livesData) async {
    final now = DateTime.now();
    final lastRegeneration = (livesData['lastRegenerationAt'] as Timestamp?)?.toDate();
    final regenerationIntervalHours = livesData['regenerationIntervalHours'] ?? 2;
    
    if (lastRegeneration != null && _currentLives < _maxLives) {
      final hoursSinceLastRegen = now.difference(lastRegeneration).inHours;
      final livesToAdd = (hoursSinceLastRegen / regenerationIntervalHours).floor();
      
      if (livesToAdd > 0) {
        _currentLives = (_currentLives + livesToAdd).clamp(0, _maxLives);
        await _updateUserLives();
      }
    }
  }

  // Update user lives in Firebase
  Future<void> _updateUserLives() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'gameStats.lives.current': _currentLives,
          'gameStats.lives.lastRegenerationAt': Timestamp.now(),
        });
      }
    } catch (e) {
      debugPrint('Error updating user lives: $e');
    }
  }

  // Create or update game session
  Future<String?> createGameSession(String quizId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final sessionData = {
          'userId': user.uid,
          'quizId': quizId,
          'startedAt': Timestamp.now(),
          'completedAt': null,
          'livesUsed': 0,
          'currentLives': _currentLives,
          'status': 'active',
          'score': 0,
          'questionsAnswered': 0,
          'correctAnswers': 0,
          'wrongAnswers': 0,
          'hintsUsed': 0,
        };
        
        final docRef = await _firestore
            .collection('userGameSessions')
            .add(sessionData);
        
        _currentGameSessionId = docRef.id;
        return docRef.id;
      }
    } catch (e) {
      debugPrint('Error creating game session: $e');
    }
    return null;
  }

  // Update game session when life is lost
  Future<void> _updateGameSessionOnLifeLoss() async {
    try {
      if (_currentGameSessionId != null) {
        await _firestore
            .collection('userGameSessions')
            .doc(_currentGameSessionId!)
            .update({
          'livesUsed': FieldValue.increment(1),
          'currentLives': _currentLives,
          'wrongAnswers': FieldValue.increment(1),
        });
      }
      
      // Update user's current lives
      await _updateUserLives();
    } catch (e) {
      debugPrint('Error updating game session: $e');
    }
  }

  // Complete game session
  Future<void> completeGameSession() async {
    try {
      if (_currentGameSessionId != null) {
        await _firestore
            .collection('userGameSessions')
            .doc(_currentGameSessionId!)
            .update({
          'completedAt': Timestamp.now(),
          'status': 'completed',
          'score': score,
          'questionsAnswered': currentQuestion + 1,
          'correctAnswers': _getCorrectAnswersCount(),
        });
      }
    } catch (e) {
      debugPrint('Error completing game session: $e');
    }
  }

  // Helper method to count correct answers
  int _getCorrectAnswersCount() {
    // This is a simplified approach - in a real app, you'd track this properly
    return (score / 10).round(); // Assuming 10 points per correct answer
  }

  // Reduce life when answer is wrong
  Future<void> reduceLife() async {
    if (_currentLives > 0) {
      _currentLives--;
      _isLifeAnimating = true;
      
      // Update Firebase
      await _updateGameSessionOnLifeLoss();
      
      // Stop animation after delay
      Future.delayed(const Duration(milliseconds: 300), () {
        _isLifeAnimating = false;
      });
      
      // Check if game over
      if (_currentLives <= 0) {
        _gameOver = true;
      }
    }
  }

  // Reset lives for new game
  void resetLives() {
    _currentLives = _maxLives;
    _gameOver = false;
    _isLifeAnimating = false;
    _currentGameSessionId = null;
  }

  // Check if player can continue
  bool canContinue() {
    return _currentLives > 0 && !_gameOver;
  }

  // Initialize lives from Firebase user data
  void initializeLives(int lives) {
    _currentLives = lives;
    _maxLives = 5; // This can be fetched from gameConfiguration
  }

  // Enhanced restart method that includes lives reset
  void restartQuizWithLives() {
    restartQuiz();
    resetLives();
  }

  // Get time until next life regeneration
  Future<Duration?> getTimeUntilNextLife() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data();
          final gameStats = userData?['gameStats'] as Map<String, dynamic>?;
          
          if (gameStats != null) {
            final lives = gameStats['lives'] as Map<String, dynamic>?;
            if (lives != null) {
              final lastRegeneration = (lives['lastRegenerationAt'] as Timestamp?)?.toDate();
              final regenerationIntervalHours = lives['regenerationIntervalHours'] ?? 2;
              
              if (lastRegeneration != null && _currentLives < _maxLives) {
                final nextRegenTime = lastRegeneration.add(Duration(hours: regenerationIntervalHours));
                final now = DateTime.now();
                
                if (nextRegenTime.isAfter(now)) {
                  return nextRegenTime.difference(now);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting time until next life: $e');
    }
    return null;
  }
}