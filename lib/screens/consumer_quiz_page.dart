import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ConsumerQuizPage extends StatefulWidget {
  const ConsumerQuizPage({super.key});

  @override
  ConsumerQuizPageState createState() => ConsumerQuizPageState();
}

class ConsumerQuizPageState extends State<ConsumerQuizPage> {
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  int _currentQuestion = 0;
  bool _answered = false;
  bool _isCorrect = false;
  String _explanation = '';
  int _score = 0;
  int _totalQuestions = 0;

  @override
  void initState() {
    super.initState();
    _loadQuizFromFirestore();
  }

  Future<void> _loadQuizFromFirestore() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('quiz')
          .doc('consumer_affairs_quiz')
          .get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        
        // Assuming the quiz questions are stored as an array in the document
        final questionsData = data['questions'] as List<dynamic>? ?? [];
        
        setState(() {
          _questions = questionsData.map((q) => _convertFirestoreQuestion(q)).toList();
          _totalQuestions = _questions.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Quiz not found in database';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading quiz: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _convertFirestoreQuestion(Map<String, dynamic> firestoreQuestion) {
    // Convert Firestore question format to local format
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

  void _answerQuestion(bool correct, String explanation, int points) {
    setState(() {
      _answered = true;
      _isCorrect = correct;
      _explanation = explanation;
      if (correct) {
        _score += points;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _answered = false;
        _isCorrect = false;
        _explanation = '';
      });
    } else {
      _showQuizComplete();
    }
  }

  void _showQuizComplete() async {
    final percentage = ((_score / _getTotalPossibleScore()) * 100).round();

    // ✅ Upload the score to Firestore
    await _uploadScoreToFirestore();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Quiz Complete!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                percentage >= 70 ? Icons.celebration : Icons.info,
                size: 64,
                color: percentage >= 70 ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Score: $_score/${_getTotalPossibleScore()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text('Percentage: $percentage%'),
              const SizedBox(height: 8),
              Text(
                percentage >= 70 ? 'Excellent work!' : 'Keep studying!',
                style: TextStyle(
                  color: percentage >= 70 ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restartQuiz();
              },
              child: const Text('Restart Quiz'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadScoreToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user is currently logged in.');
        return;
      }

      final scoreDoc = {
        'userId': user.uid,
        'quizId': 'consumer_affairs_quiz',
        'score': _score,
        'total': _getTotalPossibleScore(),
        'completedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('scores').add(scoreDoc);
      print('Score uploaded successfully.');
    } catch (e) {
      print('Failed to upload score: $e');
    }
  }



  void _restartQuiz() {
    setState(() {
      _currentQuestion = 0;
      _answered = false;
      _isCorrect = false;
      _explanation = '';
      _score = 0;
    });
  }

  int _getTotalPossibleScore() {
    return _questions.fold(0, (sum, question) => sum + (question['points'] as int));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Consumer Affairs Quiz'),
          backgroundColor: Colors.blue.shade50,
          titleTextStyle: const TextStyle(
            color: Colors.blue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.blue),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading quiz...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Consumer Affairs Quiz'),
          backgroundColor: Colors.blue.shade50,
          titleTextStyle: const TextStyle(
            color: Colors.blue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.blue),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _loadQuizFromFirestore();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Consumer Affairs Quiz'),
        ),
        body: const Center(
          child: Text('No questions available'),
        ),
      );
    }

    final question = _questions[_currentQuestion];
    final currentPoints = question['points'] as int;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumer Affairs Quiz'),
        backgroundColor: Colors.blue.shade50,
        titleTextStyle: const TextStyle(
          color: Colors.blue,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.blue),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Score: $_score',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
            stops: const [0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question header with metadata
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${question['difficulty']}'.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          Text(
                            '$currentPoints pts',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Question:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        question['question'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Answer options
                ...(question['answers'] as List<Map<String, Object>>).map((answer) {
                  final isCorrect = answer['correct'] as bool;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: AnimatedOpacity(
                      opacity: _answered ? (isCorrect ? 1.0 : 0.7) : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: ElevatedButton(
                        onPressed: _answered
                            ? null
                            : () => _answerQuestion(
                                  isCorrect,
                                  question['explanation'] as String,
                                  currentPoints,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _answered
                              ? (isCorrect
                                  ? Colors.green.shade100
                                  : Colors.red.shade50)
                              : Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _answered
                                  ? (isCorrect
                                      ? Colors.green
                                      : Colors.red.withOpacity(0.3))
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          answer['text'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _answered && isCorrect
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _answered && isCorrect
                                ? Colors.green.shade800
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Explanation and next button
                if (_answered)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isCorrect
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isCorrect
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isCorrect ? Icons.check_circle : Icons.cancel,
                              color: _isCorrect ? Colors.green : Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isCorrect 
                                  ? 'Correct! (+$currentPoints pts)' 
                                  : 'Incorrect.',
                              style: TextStyle(
                                color: _isCorrect
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Explanation:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_explanation),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _nextQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _currentQuestion < _questions.length - 1
                                  ? 'Next Question'
                                  : 'Finish Quiz',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Progress indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        'Question ${_currentQuestion + 1} of ${_questions.length}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _questions.length; i++)
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _currentQuestion
                                    ? Colors.blue.shade600
                                    : i < _currentQuestion
                                        ? Colors.green.shade400
                                        : Colors.grey.shade300,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}