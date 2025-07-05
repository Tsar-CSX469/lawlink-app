import 'package:flutter/material.dart';
import 'package:lawlink/screens/chatbot_page.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Navigate to the chat page from anywhere in the app
  static void navigateToChat() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatbotPage()),
      );
    }
  }

  /// Navigate to a specific route
  static void navigateTo(String routeName, {Object? arguments}) {
    navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
  }

  /// Pop current route
  static void goBack() {
    navigatorKey.currentState?.pop();
  }

  /// Get current context
  static BuildContext? get currentContext => navigatorKey.currentContext;
}
