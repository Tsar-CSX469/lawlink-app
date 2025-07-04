import 'package:flutter/material.dart';
import 'package:lawlink/services/consumer_quiz_service.dart';
import 'package:lawlink/widgets/quiz_question_widget.dart';
import 'package:lawlink/widgets/quiz_completion_dialog.dart';

class ConsumerQuizPage extends StatefulWidget {
  const ConsumerQuizPage({super.key});

  @override
  ConsumerQuizPageState createState() => ConsumerQuizPageState();
}

class ConsumerQuizPageState extends State<ConsumerQuizPage> {
  final ConsumerQuizService _quizService = ConsumerQuizService();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
    _pageController = PageController();
  }

  // Initialize quiz with lives system
  Future<void> _initializeQuiz() async {
    await _quizService.loadUserLives();
    await _quizService.loadQuizFromFirestore();
    
    // Create game session when quiz starts
    if (_quizService.questions.isNotEmpty) {
      await _quizService.createGameSession('consumer_affairs_quiz');
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_quizService.isLoading) {
      return _buildLoadingScaffold(context);
    }

    if (_quizService.errorMessage.isNotEmpty) {
      return _buildErrorScaffold(context);
    }

    if (_quizService.questions.isEmpty) {
      return _buildEmptyScaffold(context);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.blue.shade50],
                stops: const [0.7, 1.0],
              ),
            ),
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
          ),
          SafeArea(
            bottom: true,
            maintainBottomViewPadding: true,
            child: IgnorePointer(
              ignoring: _quizService.gameOver,
              child: QuizQuestionWidget(
                quizService: _quizService,
                onAnswer: (correct, explanation, points, answerIndex) async {
                  setState(() {
                    _quizService.answerQuestion(
                        correct, explanation, points, answerIndex);
                  });
                  
                  // Handle life reduction through service (includes database update)
                  if (!correct) {
                    await _quizService.reduceLife();
                    
                    // Check if game over after life reduction
                    if (_quizService.gameOver) {
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        if (mounted) {
                          _showGameOverDialog();
                        }
                      });
                    }
                  }
                  
                  // Update UI after life changes
                  setState(() {});
                },
                onNext: () async {
                  if (_quizService.currentQuestion <
                      _quizService.questions.length - 1) {
                    setState(() {
                      _quizService.nextQuestion();
                    });
                  } else {
                    // Complete game session when quiz finishes
                    await _quizService.completeGameSession();
                    
                    if (mounted) {
                      QuizCompletionDialog.show(context, _quizService,
                          onRestart: () async {
                        await _quizService.loadUserLives(); // Reload current lives
                        await _quizService.createGameSession('consumer_affairs_quiz'); // New session
                        setState(() {
                          _quizService.restartQuizWithLives();
                        });
                      });
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivesIndicator() {
    final currentLives = _quizService.currentLives;
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: currentLives > 2 ? Colors.green.shade100 : 
               currentLives > 1 ? Colors.orange.shade100 : 
               Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: currentLives > 2 ? Colors.green.shade300 : 
                 currentLives > 1 ? Colors.orange.shade300 : 
                 Colors.red.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _quizService.isLifeAnimating ? Icons.heart_broken : Icons.favorite,
              color: currentLives > 2 ? Colors.green.shade600 : 
                     currentLives > 1 ? Colors.orange.shade600 : 
                     Colors.red.shade600,
              size: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$currentLives',
            style: TextStyle(
              color: currentLives > 2 ? Colors.green.shade700 : 
                     currentLives > 1 ? Colors.orange.shade700 : 
                     Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.heart_broken, color: Colors.red.shade400, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Game Over!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You\'ve run out of lives!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Final Score: ${_quizService.score}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Duration?>(
                future: _quizService.getTimeUntilNextLife(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final duration = snapshot.data!;
                    final hours = duration.inHours;
                    final minutes = duration.inMinutes.remainder(60);
                    
                    return Text(
                      'Next life in: ${hours}h ${minutes}m',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Exit Quiz'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Check if user has lives to restart
                await _quizService.loadUserLives();
                if (_quizService.currentLives > 0) {
                  await _quizService.createGameSession('consumer_affairs_quiz');
                  setState(() {
                    _quizService.restartQuizWithLives();
                  });
                } else {
                  // Show message about no lives
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No lives available. Wait for regeneration.'),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restart Quiz'),
            ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(33, 150, 243, 0.1),
              spreadRadius: 0,
              blurRadius: 15,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: AppBar(
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
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
            // Lives indicator
            _buildLivesIndicator(),
            
            // Score container
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade500, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(33, 150, 243, 0.2),
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
                    '${_quizService.score}',
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
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
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

  Widget _buildErrorScaffold(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
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
                        color: Color.fromRGBO(0, 0, 0, 0.05),
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
                        _quizService.errorMessage,
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
                            _initializeQuiz();
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

  Widget _buildEmptyScaffold(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
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
}