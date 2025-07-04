import 'package:flutter/material.dart';
import 'package:lawlink/services/consumer_quiz_service.dart';

class QuizCompletionDialog {
  static void show(
    BuildContext context,
    ConsumerQuizService quizService,
    {required VoidCallback onRestart}) {
    final percentage =
        ((quizService.score / quizService.getTotalPossibleScore()) * 100).round();

    quizService.uploadScoreToFirestore();

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
          shadowColor: percentage >= 70
              ? Colors.blue.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
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
                  color: percentage >= 70
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
                'Your Score: ${quizService.score}/${quizService.getTotalPossibleScore()}',
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
                  onRestart();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed(
                    '/leaderboard',
                    arguments: {
                      'fromQuiz': true,
                      'quizScore': quizService.score,
                      'quizId': 'consumer_affairs_quiz',
                    },
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
}