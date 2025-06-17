import 'package:flutter/material.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  QuizPageState createState() => QuizPageState();
}

class QuizPageState extends State<QuizPage> {
  // Example questions (replace with real legal content)
  final List<Map<String, Object>> _questions = [
    {
      'question':
          'You buy a phone with a 1-year warranty. It stops working after 2 months. What should you do?',
      'answers': [
        {'text': 'Ask for a free repair or replacement', 'correct': true},
        {'text': 'Buy a new phone', 'correct': false},
        {'text': 'Do nothing', 'correct': false},
      ],
      'explanation':
          'Under Sri Lankan consumer law, you have the right to a free repair or replacement during the warranty period.',
    },
    {
      'question': 'A shop refuses to give you a receipt. Is this legal?',
      'answers': [
        {'text': 'Yes', 'correct': false},
        {'text': 'No', 'correct': true},
      ],
      'explanation':
          'According to the Consumer Affairs Authority Act, shops must provide receipts for purchases.',
    },
    // Add more questions as needed
  ];

  int _currentQuestion = 0;
  bool _answered = false;
  bool _isCorrect = false;
  String _explanation = '';

  void _answerQuestion(bool correct, String explanation) {
    setState(() {
      _answered = true;
      _isCorrect = correct;
      _explanation = explanation;
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestion = (_currentQuestion + 1) % _questions.length;
      _answered = false;
      _isCorrect = false;
      _explanation = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestion];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Law Quiz'),
        backgroundColor: Colors.blue.shade50,
        titleTextStyle: const TextStyle(
          color: Colors.blue,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.blue),
        elevation: 0,
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
                ...(question['answers'] as List<Map<String, Object>>).map((
                  answer,
                ) {
                  final isCorrect = answer['correct'] as bool;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: AnimatedOpacity(
                      opacity: _answered ? (isCorrect ? 1.0 : 0.7) : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: ElevatedButton(
                        onPressed:
                            _answered
                                ? null
                                : () => _answerQuestion(
                                  isCorrect,
                                  question['explanation'] as String,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _answered
                                  ? (isCorrect
                                      ? Colors.green.shade100
                                      : Colors.red.shade50)
                                  : Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  _answered
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
                            fontWeight:
                                _answered && isCorrect
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                _answered && isCorrect
                                    ? Colors.green.shade800
                                    : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 24),

                if (_answered)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          _isCorrect
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            _isCorrect
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
                              _isCorrect ? 'Correct!' : 'Incorrect.',
                              style: TextStyle(
                                color:
                                    _isCorrect
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
                            child: const Text('Next Question'),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Progress indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _questions.length; i++)
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                i == _currentQuestion
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade300,
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
}
