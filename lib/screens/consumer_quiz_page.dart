import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/quiz_api_service.dart';

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
  int _selectedAnswerIndex = -1; // Track which answer the user selected
  String? _correctOptionId; // Track the correct option ID from API response
  List<QuizAnswer> _userAnswers =
      []; // Track all user answers for API submission
  DateTime? _quizStartTime;
  DateTime? _questionStartTime;

  // Animation controller for page transitions
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _loadQuizFromApi();
    _pageController = PageController();
    _quizStartTime = DateTime.now();
    _questionStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizFromApi() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load quiz using Firebase Function instead of direct Firestore access
      final quiz = await QuizApiService.getQuiz('consumer_affairs_quiz');

      // Convert API response to existing format for compatibility
      final questionsData = quiz['questions'] as List<dynamic>? ?? [];
      setState(() {
        _questions = questionsData.map((q) => _convertApiQuestion(q)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading quiz: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _convertApiQuestion(Map<String, dynamic> apiQuestion) {
    // Convert API question format to existing local format for compatibility
    final options = apiQuestion['options'] as List<dynamic>;

    return {
      'question': apiQuestion['question'] as String,
      'answers':
          options.map((option) {
            final optionMap = option as Map<String, dynamic>;
            return {
              'text': optionMap['text'] as String,
              'correct':
                  false, // We don't know the correct answer from API (security)
            };
          }).toList(),
      'explanation': '', // Will be provided after submission
      'points': apiQuestion['points'] as int? ?? 10,
      'category': apiQuestion['category'] as String? ?? '',
      'difficulty': apiQuestion['difficulty'] as String? ?? 'medium',
      'references': apiQuestion['references'] as List<dynamic>? ?? [],
      'id': apiQuestion['id'] as String, // Store question ID for API submission
      'options': options, // Store original options for API submission
    };
  }

  Future<void> _validateAnswerRealTime(int answerIndex) async {
    final question = _questions[_currentQuestion];
    final selectedOption = question['options'][answerIndex];

    try {
      // Call the API to validate the answer in real-time
      final validation = await QuizApiService.validateAnswer(
        quizId: 'consumer_affairs_quiz',
        questionId: question['id'],
        selectedOptionId: selectedOption['id'],
      );

      // Update the UI with real-time feedback
      _answerQuestion(
        validation['isCorrect'] as bool,
        validation['explanation'] as String? ?? '',
        validation['points'] as int? ?? 0,
        correctOptionId: validation['correctOptionId'] as String?,
        answerIndex: answerIndex,
      );
    } catch (e) {
      // If validation fails, provide neutral feedback
      _answerQuestion(
        false,
        'Unable to validate answer at this time.',
        0,
        answerIndex: answerIndex,
        correctOptionId: null, // No correct answer info available
      );
      print('Error validating answer: $e');
    }
  }

  void _answerQuestion(
    bool correct,
    String explanation,
    int points, {
    int? answerIndex,
    String? correctOptionId,
  }) {
    // Record the user's answer for API submission
    final question = _questions[_currentQuestion];
    final questionStartTime = _questionStartTime ?? DateTime.now();
    final timeSpent = DateTime.now().difference(questionStartTime).inSeconds;

    if (answerIndex != null && question['options'] != null) {
      final selectedOption = question['options'][answerIndex];
      final userAnswer = QuizAnswer(
        questionId: question['id'],
        selectedOptionId: selectedOption['id'],
        timeSpent: timeSpent,
      );
      _userAnswers.add(userAnswer);
    }

    setState(() {
      _answered = true;
      _isCorrect = correct;
      _explanation = explanation;
      _selectedAnswerIndex = answerIndex ?? -1;
      _correctOptionId = correctOptionId; // Store the correct option ID
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
        _selectedAnswerIndex = -1; // Reset the selected answer index
        _correctOptionId = null; // Reset the correct option ID
        _questionStartTime = DateTime.now(); // Reset question start time
      });
    } else {
      _submitQuizToApi();
    }
  }

  Future<void> _submitQuizToApi() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('You must be logged in to submit the quiz.');
        return;
      }

      final quizStartTime = _quizStartTime ?? DateTime.now();
      final totalDuration = DateTime.now().difference(quizStartTime).inSeconds;

      // Submit using Firebase Function
      final result = await QuizApiService.submitQuiz(
        quizId: 'consumer_affairs_quiz',
        userId: user.uid,
        answers: _userAnswers.map((a) => a.toJson()).toList(),
        duration: totalDuration,
      );

      // Parse the result and update the score
      final quizResult = QuizResult.fromJson(result);

      setState(() {
        _score = quizResult.score;
      });

      // Show the quiz complete dialog with real results
      _showQuizCompleteDialog(quizResult);
    } catch (e) {
      String errorMessage = e.toString();

      // Handle specific timing errors with better UI
      if (errorMessage.contains('⏱️') || errorMessage.contains('too fast')) {
        _showTimingErrorDialog(
          'Submission Too Fast',
          'Please take more time to read and answer each question carefully. This ensures fair assessment for all users.',
          'I\'ll Take More Time',
        );
      } else if (errorMessage.contains('⏰') ||
          errorMessage.contains('time limit exceeded')) {
        _showTimingErrorDialog(
          'Time Limit Exceeded',
          'You have exceeded the maximum time allowed for this quiz. Please try again and complete within the time limit.',
          'Try Again',
        );
      } else {
        _showErrorDialog(
          'Failed to submit quiz: ${errorMessage.replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  void _showTimingErrorDialog(String title, String message, String buttonText) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                title.contains('Fast') ? Icons.timer_off : Icons.timer,
                color: title.contains('Fast') ? Colors.orange : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                title.contains('Fast')
                    ? Icons.slow_motion_video
                    : Icons.access_time,
                size: 60,
                color:
                    title.contains('Fast')
                        ? Colors.orange.shade300
                        : Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (title.contains('Fast')) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Minimum time: 5 seconds per question',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset quiz to allow retry
                if (title.contains('Fast')) {
                  setState(() {
                    _currentQuestion = 0;
                    _answered = false;
                    _isCorrect = false;
                    _explanation = '';
                    _score = 0; // Reset the score
                    _selectedAnswerIndex = -1;
                    _correctOptionId = null; // Reset the correct option ID
                    _userAnswers.clear();
                    _quizStartTime = DateTime.now();
                    _questionStartTime = DateTime.now();
                  });
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor:
                    title.contains('Fast') ? Colors.orange : Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
    );
  }

  void _showQuizCompleteDialog(QuizResult result) {
    final percentage = result.percentage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor:
              percentage >= 70
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
          title: ShaderMask(
            shaderCallback:
                (bounds) => LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
            child: const Text(
              'Quiz Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                curve: Curves.elasticOut,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      percentage >= 70
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  percentage >= 70 ? Icons.emoji_events : Icons.info,
                  size: 64,
                  color: percentage >= 70 ? Colors.amber : Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Score: $_score/${_getTotalPossibleScore()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Percentage: $percentage%'),
              const SizedBox(height: 8),
              Column(
                children: [
                  Text(
                    percentage >= 70 ? 'Excellent work!' : 'Keep studying!',
                    style: TextStyle(
                      color: percentage >= 70 ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (percentage >= 70)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'You\'ve mastered this topic! Check the leaderboard to see how you rank.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200.withOpacity(0.5),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restartQuiz();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text('Restart Quiz'),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200.withOpacity(0.5),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop(); // Close the dialog                  // Navigate to leaderboard with a slide animation
                  Navigator.of(context).pushReplacementNamed(
                    '/leaderboard',
                    arguments: {
                      'fromQuiz': true,
                      'quizScore': _score,
                      'quizId': 'consumer_affairs_quiz',
                    },
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                child: const Text('View Leaderboard'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestion = 0;
      _answered = false;
      _isCorrect = false;
      _explanation = '';
      _score = 0;
      _selectedAnswerIndex = -1;
      _correctOptionId = null; // Reset the correct option ID
      _userAnswers.clear();
      _quizStartTime = DateTime.now();
      _questionStartTime = DateTime.now();
    });
  }

  int _getTotalPossibleScore() {
    return _questions.fold(
      0,
      (sum, question) => sum + (question['points'] as int),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AppBar(
              title: ShaderMask(
                shaderCallback:
                    (bounds) => LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                child: const Text(
                  'Consumer Quiz',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              iconTheme: IconThemeData(color: Colors.blue.shade700),
            ),
          ),
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
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 20),
                Text(
                  'Loading quiz questions...',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AppBar(
              title: ShaderMask(
                shaderCallback:
                    (bounds) => LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                child: const Text(
                  'Consumer Quiz',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              iconTheme: IconThemeData(color: Colors.blue.shade700),
            ),
          ),
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          spreadRadius: 0,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 70,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error Loading Quiz',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = '';
                              });
                              _loadQuizFromApi();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AppBar(
              title: ShaderMask(
                shaderCallback:
                    (bounds) => LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                child: const Text(
                  'Consumer Quiz',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              iconTheme: IconThemeData(color: Colors.blue.shade700),
            ),
          ),
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
          child: const Center(
            child: Text(
              'No questions available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestion];
    final currentPoints = question['points'] as int;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 15,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: AppBar(
            title: ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
              child: const Text(
                'Consumer Quiz',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.blue.shade700),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade500, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$_score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background container with gradient that stays fixed
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.blue.shade50],
                stops: const [0.7, 1.0],
              ),
            ),
            // Make sure it fills the entire screen
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
          ),

          // Scrollable content that scrolls over the fixed background
          SafeArea(
            bottom: true,
            maintainBottomViewPadding: true,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question header with metadata
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 15,
                            spreadRadius: 0,
                            offset: const Offset(0, 5),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _getDifficultyGradient(
                                      question['difficulty'] as String,
                                    ),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getDifficultyColor(
                                        question['difficulty'] as String,
                                      ).withOpacity(0.2),
                                      blurRadius: 5,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${question['difficulty']}'.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  // color: Colors.blue.shade700,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 4),
                                    Text(
                                      '$currentPoints pts',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            question['question'] as String,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                              height: 1.4,
                            ),
                          ),
                          if (question['category'] != null &&
                              (question['category'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Category: ${question['category']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Progress indicator (moved to top)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Question ${_currentQuestion + 1} of ${_questions.length}',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${((_currentQuestion + 1) / _questions.length * 100).round()}%',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                  width:
                                      (MediaQuery.of(context).size.width - 48) *
                                      ((_currentQuestion + 1) /
                                          _questions.length),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade500,
                                        Colors.blue.shade800,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Answer options
                    ...(question['answers'] as List<Map<String, Object>>).map((
                      answer,
                    ) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: IntrinsicHeight(
                          child: Stack(
                            children: [
                              // Answer button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.05),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap:
                                        _answered
                                            ? null
                                            : () {
                                              // Find the index of this answer in the list
                                              final answerIndex =
                                                  (question['answers']
                                                          as List<
                                                            Map<String, Object>
                                                          >)
                                                      .indexWhere(
                                                        (a) => a == answer,
                                                      );
                                              // Use real-time validation instead of hardcoded values
                                              _validateAnswerRealTime(
                                                answerIndex,
                                              );
                                            },
                                    borderRadius: BorderRadius.circular(16),
                                    splashColor: Colors.blue.withOpacity(0.1),
                                    highlightColor: Colors.blue.withOpacity(
                                      0.05,
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _getAnswerGradient(answer),
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _getBorderColor(answer),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 20,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                answer['text'] as String,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      _answered &&
                                                              _isAnswerSelected(
                                                                answer,
                                                              )
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                  color: _getAnswerTextColor(
                                                    answer,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_answered &&
                                                (_isAnswerSelected(answer) ||
                                                    _isCorrectAnswer(answer)))
                                              Icon(
                                                // Show green checkmark for correct answer, red X for incorrect selected answer
                                                _isCorrectAnswer(answer)
                                                    ? Icons
                                                        .check_circle_outline_rounded
                                                    : Icons.cancel_outlined,
                                                color:
                                                    _isCorrectAnswer(answer)
                                                        ? Colors.green.shade700
                                                        : Colors.red.shade700,
                                                size: 24,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 16),

                    // Explanation and next button
                    if (_answered)
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              _isCorrect
                                  ? Colors.green.shade50.withOpacity(0.3)
                                  : Colors.red.shade50.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                _isCorrect
                                    ? Colors.green.shade200
                                    : Colors.red.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _isCorrect
                                      ? Colors.green.shade200.withOpacity(0.2)
                                      : Colors.red.shade200.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        _isCorrect
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isCorrect
                                        ? Icons.check_rounded
                                        : Icons.close_rounded,
                                    color:
                                        _isCorrect
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _isCorrect
                                        ? 'Correct! (+$currentPoints pts)'
                                        : 'Incorrect.',
                                    style: TextStyle(
                                      color:
                                          _isCorrect
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Explanation text
                            Text(
                              _explanation,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade900,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Next Question button - moved higher
                            Container(
                              width: double.infinity,
                              height: 50,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade700,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade700.withOpacity(
                                      0.3,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _nextQuestion,
                                  borderRadius: BorderRadius.circular(16),
                                  splashColor: Colors.white.withOpacity(0.1),
                                  highlightColor: Colors.transparent,
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _currentQuestion <
                                                  _questions.length - 1
                                              ? 'Next Question'
                                              : 'Finish Quiz',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          _currentQuestion <
                                                  _questions.length - 1
                                              ? Icons.arrow_forward_rounded
                                              : Icons
                                                  .check_circle_outline_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
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
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for UI
  List<Color> _getDifficultyGradient(String difficulty) {
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

  Color _getDifficultyColor(String difficulty) {
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

  List<Color> _getAnswerGradient(Map<String, Object> answer) {
    if (!_answered) {
      return [Colors.white, Colors.white];
    }

    // Check if this is the correct answer (always highlight in green when answered)
    if (_isCorrectAnswer(answer)) {
      return [Colors.green.shade50, Colors.green.shade100];
    }

    // Check if this is the selected answer and it's incorrect
    if (_isAnswerSelected(answer) && !_isCorrect) {
      return [Colors.red.shade50, Colors.red.shade100];
    }

    // Unselected answers become faded when an answer is selected
    return [Colors.white.withOpacity(0.7), Colors.white.withOpacity(0.7)];
  }

  Color _getAnswerTextColor(Map<String, Object> answer) {
    if (!_answered) {
      return Colors.grey.shade800;
    }

    // Check if this is the correct answer (always green text when answered)
    if (_isCorrectAnswer(answer)) {
      return Colors.green.shade800;
    }

    // Check if this is the selected answer and it's incorrect
    if (_isAnswerSelected(answer) && !_isCorrect) {
      return Colors.red.shade800;
    }

    // Unselected answers become faded gray when an answer is selected
    return Colors.grey.shade500;
  }

  Color _getBorderColor(Map<String, Object> answer) {
    if (!_answered) {
      return Colors.grey.shade200;
    }

    // Check if this is the correct answer (always green border when answered)
    if (_isCorrectAnswer(answer)) {
      return Colors.green.shade300;
    }

    // Check if this is the selected answer and it's incorrect
    if (_isAnswerSelected(answer) && !_isCorrect) {
      return Colors.red.shade300;
    }

    // Unselected answers keep light gray border when an answer is selected
    return Colors.grey.shade200;
  }

  bool _isAnswerSelected(Map<String, Object> answer) {
    if (!_answered) return false;
    return answer ==
        _questions[_currentQuestion]['answers'][_selectedAnswerIndex];
  }

  // Helper method to check if an answer option is the correct one
  bool _isCorrectAnswer(Map<String, Object> answer) {
    if (!_answered || _correctOptionId == null) return false;

    // Find the option in the original options array that matches this answer
    final question = _questions[_currentQuestion];
    final options = question['options'] as List<dynamic>?;

    if (options == null) return false;

    // Find the matching option by text and check its ID
    for (final option in options) {
      if (option is Map<String, dynamic> && option['text'] == answer['text']) {
        return option['id'] == _correctOptionId;
      }
    }

    return false;
  }
}
