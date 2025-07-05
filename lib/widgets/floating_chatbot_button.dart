import 'package:flutter/material.dart';
import 'package:lawlink/screens/chatbot_page.dart';
import 'package:lawlink/services/chatbot_initialization_service.dart';

class FloatingChatbotButton extends StatefulWidget {
  const FloatingChatbotButton({super.key});

  @override
  State<FloatingChatbotButton> createState() => _FloatingChatbotButtonState();
}

class _FloatingChatbotButtonState extends State<FloatingChatbotButton> {
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    // Start initialization in background when button is first created
    _initializeInBackground();
  }

  void _initializeInBackground() async {
    if (!ChatbotInitializationService.isReady) {
      await ChatbotInitializationService.initializeAsync(context: context);
    }
  }

  void _handleChatButtonPress() async {
    // If not initialized, show initialization process
    if (!ChatbotInitializationService.isReady) {
      setState(() {
        _isInitializing = true;
      });

      // Show a friendly loading message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(ChatbotInitializationService.getStatusMessage()),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Initialize the service
      final success = await ChatbotInitializationService.initializeAsync(
        context: context,
      );

      setState(() {
        _isInitializing = false;
      });

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to initialize AI chat. Please try again.',
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
    }

    // Check for missing permissions and handle them gracefully
    final permissionsOk =
        await ChatbotInitializationService.checkAndRequestMissingPermissions(
          context,
        );

    if (!permissionsOk) {
      // User can still use chat without some permissions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You can still use text chat. Voice features may be limited.',
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    // Navigate to chat page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatbotPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReady = ChatbotInitializationService.isReady;
    final status = ChatbotInitializationService.initializationStatus;

    return Positioned(
      bottom: 20,
      right: 20,
      child: Stack(
        children: [
          FloatingActionButton(
            heroTag: "chatbot_fab", // Unique tag to avoid conflicts
            onPressed: _handleChatButtonPress,
            backgroundColor:
                _isInitializing
                    ? Colors.orange.shade600
                    : isReady
                    ? Colors.blue.shade600
                    : Colors.grey.shade400,
            foregroundColor: Colors.white,
            child:
                _isInitializing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : isReady
                    ? const Icon(Icons.chat_bubble_outline)
                    : const Icon(Icons.chat_bubble_outline_outlined),
          ),
          // Small status indicator
          if (!isReady && !_isInitializing)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color:
                      status['permissions'] == true
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
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
