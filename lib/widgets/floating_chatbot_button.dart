import 'package:flutter/material.dart';
import 'package:lawlink/screens/chatbot_page.dart';

class FloatingChatbotButton extends StatelessWidget {
  const FloatingChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        heroTag: "chatbot_fab", // Unique tag to avoid conflicts
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatbotPage()),
          );
        },
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}

// Widget to wrap any screen with the chatbot functionality
class ChatbotWrapper extends StatelessWidget {
  final Widget child;

  const ChatbotWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [child, const FloatingChatbotButton()]);
  }
}
