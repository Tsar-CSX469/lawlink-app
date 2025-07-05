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
        frequency: const Duration(minutes: 15),
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

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'procedure_overdue',
          'Procedure Overdue Notifications',
          channelDescription: 'Notifications for procedures that are overdue',
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

  static Future<void> checkAndNotifyOverdueProcedures() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      final proceduresSnapshot =
          await FirebaseFirestore.instance
              .collection('user_procedures')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'In Progress')
              .get();

      for (var doc in proceduresSnapshot.docs) {
        final data = doc.data();
        final statusUpdatedAt = data['statusUpdatedAt'] as Timestamp?;

        if (statusUpdatedAt != null) {
          final statusDateTime = statusUpdatedAt.toDate();

          // Check if the procedure has been "In Progress" for more than 1 hour
          if (statusDateTime.isBefore(oneHourAgo)) {
            final procedureName = data['procedureName'] ?? 'Unknown Procedure';

            // Check if we've already sent a notification for this procedure
            final notificationSent = data['overdueNotificationSent'] ?? false;

            if (!notificationSent) {
              await showNotification(
                id: doc.id.hashCode,
                title: 'Procedure Overdue',
                body:
                    'Your procedure "$procedureName" has been in progress for over an hour. Consider checking its status.',
              );

              // Mark that we've sent the notification
              await doc.reference.update({'overdueNotificationSent': true});
            }
          }
        }
      }
    } catch (e) {
      print('Error checking overdue procedures: $e');
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
}
