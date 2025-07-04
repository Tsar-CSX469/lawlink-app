import 'package:flutter/material.dart';
import 'package:lawlink/services/consumer_quiz_service.dart';
import 'package:lawlink/widgets/quiz_answer_widget.dart';

class QuizQuestionWidget extends StatelessWidget {
  final ConsumerQuizService quizService;
  final Function(bool, String, int, int) onAnswer;
  final VoidCallback onNext;

  const QuizQuestionWidget({
    super.key,
    required this.quizService,
    required this.onAnswer,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final question = quizService.questions[quizService.currentQuestion];
    final currentPoints = question['points'] as int;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    color: Colors.blue.withValues(alpha: 0.1),
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
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: quizService.getDifficultyGradient(
                                question['difficulty'] as String),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: quizService.getDifficultyColor(
                                  question['difficulty'] as String).withValues(alpha: 0.2),
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
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
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
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.1),
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
                        'Question ${quizService.currentQuestion + 1} of ${quizService.questions.length}',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${((quizService.currentQuestion + 1) / quizService.questions.length * 100).round()}%',
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
                          width: (MediaQuery.of(context).size.width - 48) *
                              ((quizService.currentQuestion + 1) /
                                  quizService.questions.length),
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
                                color: Colors.blue.withValues(alpha: 0.3),
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
            ...(question['answers'] as List<Map<String, Object>>).asMap().entries.map((entry) {
              final index = entry.key;
              final answer = entry.value;
              return QuizAnswerWidget(
                answer: answer,
                isCorrect: answer['correct'] as bool,
                isAnswered: quizService.answered,
                isSelected: index == quizService.selectedAnswerIndex,
                onTap: () {
                  if (!quizService.answered) {
                    onAnswer(
                      answer['correct'] as bool,
                      question['explanation'] as String,
                      currentPoints,
                      index,
                    );
                   }
                },
              );
            }),
            if (quizService.answered)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: quizService.isCorrect
                      ? Colors.green.shade50.withValues(alpha: 0.3)
                      : Colors.red.shade50.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: quizService.isCorrect
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: quizService.isCorrect
                          ? Colors.green.shade200.withValues(alpha: 0.2)
                          : Colors.red.shade200.withValues(alpha: 0.2),
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
                            color: quizService.isCorrect
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            quizService.isCorrect
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: quizService.isCorrect
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            quizService.isCorrect
                                ? 'Correct! (+$currentPoints pts)'
                                : 'Incorrect.',
                            style: TextStyle(
                              color: quizService.isCorrect
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
                    Text(
                      quizService.explanation,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade900,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                            color: Colors.blue.shade700.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onNext,
                          borderRadius: BorderRadius.circular(16),
                          splashColor: Colors.white.withValues(alpha: 0.1),
                          highlightColor: Colors.transparent,
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  quizService.currentQuestion <
                                          quizService.questions.length - 1
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
                                  quizService.currentQuestion <
                                          quizService.questions.length - 1
                                      ? Icons.arrow_forward_rounded
                                      : Icons.check_circle_outline_rounded,
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
    );
  }
}