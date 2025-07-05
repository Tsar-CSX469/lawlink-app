import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lawlink/services/navigation_service.dart';
import 'dart:async';

class BackgroundChatService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final Map<String, Completer<void>> _loadingTasks = {};
  static bool _isInitialized = false;

  /// Initialize the background chat service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      print('BackgroundChatService initialized successfully');
    } catch (e) {
      print('BackgroundChatService initialization error: $e');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == 'chat_ready') {
      // Navigate to chat page
      _navigateToChat();
    }
  }

  /// Navigate to chat page (this will be called from notification)
  static void _navigateToChat() {
    NavigationService.navigateToChat();
  }

  /// Start loading chat in background and show notification when ready
  static Future<void> startBackgroundChatLoading(BuildContext context) async {
    const String taskId = 'chat_loading';

    // If already loading, don't start again
    if (_loadingTasks.containsKey(taskId)) {
      _showAlreadyLoadingSnackbar(context);
      return;
    }

    // Show loading indicator
    _showLoadingSnackbar(context);

    // Create a completer for this task
    final completer = Completer<void>();
    _loadingTasks[taskId] = completer;

    try {
      // Start the background loading process
      _performBackgroundChatLoading()
          .then((_) {
            // Chat is ready, show notification
            _showChatReadyNotification();

            // Complete the task
            if (!completer.isCompleted) {
              completer.complete();
            }
            _loadingTasks.remove(taskId);
          })
          .catchError((error) {
            // Handle error
            _showChatErrorNotification(error.toString());

            if (!completer.isCompleted) {
              completer.completeError(error);
            }
            _loadingTasks.remove(taskId);
          });
    } catch (e) {
      _loadingTasks.remove(taskId);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    }
  }

  /// Perform the actual background chat loading
  static Future<void> _performBackgroundChatLoading() async {
    // Simulate chat initialization process
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    // Initialize chatbot service if needed
    // This is where you'd actually initialize the chat service
    // For now, we'll just simulate the process

    // You could also pre-load some data here:
    // - Initialize the AI model
    // - Fetch conversation history
    // - Prepare the chat interface

    print('Chat service background loading completed');
  }

  /// Show notification when chat is ready
  static Future<void> _showChatReadyNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'chat_ready',
          'LawLink AI Chat',
          channelDescription: 'Notifications when LawLink AI chat is ready',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Colors.blue,
          ledColor: Colors.blue,
          ledOnMs: 1000,
          ledOffMs: 500,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      1001, // Unique notification ID for chat ready
      'LawLink AI is Ready! 🤖',
      'Your AI legal assistant is now ready to help. Tap to start chatting!',
      platformChannelSpecifics,
      payload: 'chat_ready',
    );
  }

  /// Show notification when chat loading fails
  static Future<void> _showChatErrorNotification(String error) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'chat_error',
          'LawLink AI Chat Error',
          channelDescription:
              'Notifications when LawLink AI chat fails to load',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Colors.red,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      1002, // Unique notification ID for chat error
      'LawLink AI Error ⚠️',
      'Unable to load AI chat. Please try again.',
      platformChannelSpecifics,
      payload: 'chat_error',
    );
  }

  /// Show snackbar indicating chat is loading
  static void _showLoadingSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Loading LawLink AI in background...'),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show snackbar indicating chat is already loading
  static void _showAlreadyLoadingSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('LawLink AI is already loading in background'),
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Check if chat is currently loading
  static bool get isChatLoading => _loadingTasks.isNotEmpty;

  /// Cancel any ongoing chat loading
  static void cancelChatLoading() {
    for (final completer in _loadingTasks.values) {
      if (!completer.isCompleted) {
        completer.completeError('Cancelled by user');
      }
    }
    _loadingTasks.clear();
  }

  /// Get the status of chat loading
  static String get loadingStatus {
    if (_loadingTasks.isEmpty) {
      return 'Ready';
    } else {
      return 'Loading...';
    }
  }
}
