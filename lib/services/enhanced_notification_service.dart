import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

// Background task callback - must be at top level
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Initialize Firebase in the background isolate
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      switch (task) {
        case "checkOverdueProceduresTask":
          await NotificationService.checkAndNotifyOverdueProcedures();
          break;
      }
    } catch (e) {
      print('Background task error: $e');
    }
    return Future.value(true);
  });
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String type;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.metadata,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'general',
      isRead: data['isRead'] ?? false,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'isRead': isRead,
      'metadata': metadata,
    };
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // Initialize local notifications
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

      await _notificationsPlugin.initialize(initializationSettings);

      // Try to initialize Workmanager for background tasks (only on supported platforms)
      await _initializeBackgroundTasks();
    } catch (e) {
      print('NotificationService initialization error: $e');
    }
  }

  static Future<void> _initializeBackgroundTasks() async {
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

      // Register the periodic task
      await Workmanager().registerPeriodicTask(
        "checkOverdueProcedures",
        "checkOverdueProceduresTask",
        frequency: const Duration(minutes: 1),
        constraints: Constraints(networkType: NetworkType.connected),
      );

      print('Background tasks initialized successfully');
    } catch (e) {
      print('Background tasks not available on this platform: $e');
      // App will continue to work with manual notification checks
    }
  }

  static Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'lawlink_general',
          'LawLink Notifications',
          channelDescription: 'General notifications from LawLink',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(id, title, body, platformChannelSpecifics);
  }

  // Enhanced notification system
  static Future<void> addNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? metadata,
    bool showLocalNotification = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final notification = NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        type: type,
        metadata: metadata,
      );

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toFirestore());

      // Show local notification if requested
      if (showLocalNotification) {
        await _showLocalNotification(
          id: notification.id.hashCode,
          title: title,
          body: body,
        );
      }
    } catch (e) {
      // Silent error handling for production
    }
  }

  static Future<List<NotificationItem>> getUserNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('user_notifications')
              .doc(user.uid)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => NotificationItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  static Future<int> getUnreadNotificationCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('user_notifications')
              .doc(user.uid)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('user_notifications')
              .doc(user.uid)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  static Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  static Future<void> deleteAllNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('user_notifications')
              .doc(user.uid)
              .collection('notifications')
              .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  // Legacy method for overdue procedures - now uses new system
  static Future<void> checkAndNotifyOverdueProcedures() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final now = DateTime.now();
      final twoSecondsAgo = now.subtract(const Duration(seconds: 2));

      final proceduresSnapshot =
          await FirebaseFirestore.instance
              .collection('user_procedures')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'In Progress')
              .get();

      for (var doc in proceduresSnapshot.docs) {
        final data = doc.data();
        final statusUpdatedAt = data['statusUpdatedAt'] as Timestamp?;
        final procedureName = data['procedureName'] ?? 'Unknown Procedure';

        if (statusUpdatedAt != null) {
          final statusDateTime = statusUpdatedAt.toDate();

          // Check if the procedure has been "In Progress" for more than 2 seconds
          if (statusDateTime.isBefore(twoSecondsAgo)) {
            // Check if we've already sent a notification for this procedure
            final notificationSent = data['overdueNotificationSent'] ?? false;

            if (!notificationSent) {
              // Get step completion details
              final completedSteps = List<int>.from(
                data['completedSteps'] ?? [],
              );
              final procedureId = data['procedureId'];

              // Get the procedure details to find total steps and incomplete ones
              String detailedBody =
                  'Your procedure "$procedureName" has been in progress for more than 2 seconds.';

              if (procedureId != null) {
                try {
                  // Get the procedure details from the legal_procedures collection
                  final procedureDoc =
                      await FirebaseFirestore.instance
                          .collection('legal_procedures')
                          .doc(procedureId)
                          .get();

                  if (procedureDoc.exists) {
                    final procedureData = procedureDoc.data();
                    final stepsData = procedureData?['steps'];

                    if (stepsData != null) {
                      List<String> allSteps = [];

                      if (stepsData is List) {
                        allSteps =
                            stepsData.map((step) => step.toString()).toList();
                      } else if (stepsData is String) {
                        allSteps = [stepsData];
                      }

                      if (allSteps.isNotEmpty) {
                        // Find incomplete steps
                        List<String> incompleteSteps = [];
                        for (int i = 0; i < allSteps.length; i++) {
                          if (!completedSteps.contains(i)) {
                            incompleteSteps.add(
                              'Step ${i + 1}: ${allSteps[i]}',
                            );
                          }
                        }

                        if (incompleteSteps.isNotEmpty) {
                          String incompleteStepsText = incompleteSteps
                              .take(3)
                              .join('\n• ');
                          if (incompleteSteps.length > 3) {
                            incompleteStepsText +=
                                '\n• ... and ${incompleteSteps.length - 3} more';
                          }

                          detailedBody =
                              'Your procedure "$procedureName" needs attention!\n\n'
                              'Progress: ${completedSteps.length}/${allSteps.length} steps completed\n\n'
                              'Remaining steps:\n• $incompleteStepsText';
                        }
                      }
                    }
                  }
                } catch (e) {
                  // Fall back to detailed notification with available information
                  detailedBody =
                      'Your procedure "$procedureName" needs attention!\n\n'
                      'You have completed ${completedSteps.length} steps so far. '
                      'Please review the procedure and continue with the remaining steps to complete it.\n\n'
                      'Completed step numbers: ${completedSteps.join(', ')}';
                }
              } else {
                // No procedure ID available, provide general detailed message
                detailedBody =
                    'Your procedure "$procedureName" needs attention!\n\n'
                    'You have completed ${completedSteps.length} steps so far. '
                    'Please continue with the remaining steps to complete the procedure.';
              }

              // Use new notification system with detailed information
              await addNotification(
                title: 'Procedure Needs Attention',
                body: detailedBody,
                type: 'procedure_overdue',
                metadata: {
                  'procedureId': doc.id,
                  'procedureName': procedureName,
                  'completedStepsCount': completedSteps.length,
                  'completedSteps': completedSteps,
                },
              );

              // Mark that we've sent the notification
              await doc.reference.update({'overdueNotificationSent': true});
            }
          }
        }
      }
    } catch (e) {
      // Silent error handling for production
    }
  }

  // fallback when background tasks are not available
  static Future<void> performPeriodicCheck() async {
    try {
      await checkAndNotifyOverdueProcedures();
    } catch (e) {
      print('Periodic check failed: $e');
    }
  }

  // Helper methods for different notification types
  static Future<void> addAchievementNotification({
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    await addNotification(
      title: title,
      body: body,
      type: 'quiz_achievement',
      metadata: metadata,
    );
  }

  static Future<void> addSystemNotification({
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    await addNotification(
      title: title,
      body: body,
      type: 'system',
      metadata: metadata,
    );
  }

  // Repair function to fix existing procedures with null status
  static Future<void> repairProceduresWithNullStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final allProceduresSnapshot =
          await FirebaseFirestore.instance
              .collection('user_procedures')
              .where('userId', isEqualTo: user.uid)
              .get();

      for (var doc in allProceduresSnapshot.docs) {
        final data = doc.data();
        final status = data['status'];
        final statusUpdatedAt = data['statusUpdatedAt'];
        final completedSteps = data['completedSteps'] as List<dynamic>?;

        bool needsRepair = false;
        Map<String, dynamic> updateData = {};

        if (status == null) {
          String newStatus;
          if (completedSteps == null || completedSteps.isEmpty) {
            newStatus = 'Not Started';
          } else {
            newStatus = 'In Progress';
          }

          updateData['status'] = newStatus;
          updateData['statusUpdatedAt'] = FieldValue.serverTimestamp();
          updateData['overdueNotificationSent'] = false;
          needsRepair = true;
        } else if (statusUpdatedAt == null && status == 'In Progress') {
          updateData['statusUpdatedAt'] = FieldValue.serverTimestamp();
          updateData['overdueNotificationSent'] = false;
          needsRepair = true;
        }

        if (needsRepair) {
          await doc.reference.update(updateData);
        }
      }
    } catch (e) {
      // Silent repair - only fix what we can
    }
  }
}
