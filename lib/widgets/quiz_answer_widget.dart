import 'package:flutter/material.dart';

class QuizAnswerWidget extends StatelessWidget {
  final Map<String, Object> answer;
  final bool isCorrect;
  final bool isAnswered;
  final bool isSelected;
  final VoidCallback onTap;

  const QuizAnswerWidget({
    super.key,
    required this.answer,
    required this.isCorrect,
    required this.isAnswered,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: IntrinsicHeight(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isAnswered && isCorrect
                        ? Colors.green.withOpacity(0.2)
                        : (isAnswered && isSelected && !isCorrect)
                            ? Colors.red.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isAnswered ? null : onTap,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: Colors.blue.withOpacity(0.1),
                  highlightColor: Colors.blue.withOpacity(0.05),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _getAnswerGradient(),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getBorderColor(),
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
                                fontWeight: isAnswered && isCorrect
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _getAnswerTextColor(),
                              ),
                            ),
                          ),
                          if (isAnswered)
                            Icon(
                              isCorrect
                                  ? Icons.check_circle_outline_rounded
                                  : (isSelected ? Icons.cancel_outlined : null),
                              color: isCorrect
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
  }

  List<Color> _getAnswerGradient() {
    if (!isAnswered) {
      return [Colors.white, Colors.white];
    }
    if (isCorrect) {
      return [Colors.green.shade50, Colors.green.shade100];
    }
    if (isSelected) {
      return [Colors.red.shade50, Colors.red.shade100];
    }
    return [Colors.white.withOpacity(0.7), Colors.white.withOpacity(0.7)];
  }

  Color _getAnswerTextColor() {
    if (!isAnswered) {
      return Colors.grey.shade800;
    }
    if (isCorrect) {
      return Colors.green.shade800;
    }
    if (isSelected) {
      return Colors.red.shade800;
    }
    return Colors.grey.shade500;
  }

  Color _getBorderColor() {
    if (!isAnswered) {
      return Colors.grey.shade200;
    }
    if (isCorrect) {
      return Colors.green.shade300;
    }
    if (isSelected) {
      return Colors.red.shade300;
    }
    return Colors.grey.shade200;
  }
}