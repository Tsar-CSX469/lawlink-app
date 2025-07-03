# Notification System for Overdue Procedures

## Overview
This system automatically sends notifications to users when their legal procedures remain "In Progress" for more than one hour.

## How it Works

### 1. Status Tracking
- When a user completes their first step in a procedure, the status changes from "Not Started" to "In Progress"
- The system records a timestamp (`statusUpdatedAt`) when this happens
- Each status change resets the `overdueNotificationSent` flag to `false`

### 2. Background Monitoring
- The app attempts to use **WorkManager** to run a background task every 15 minutes
- If WorkManager is not supported (e.g., on web platforms), the app falls back to manual checks
- The background task calls `NotificationService.checkAndNotifyOverdueProcedures()`
- This function checks all procedures that are "In Progress" for more than 1 hour

### 3. Fallback System
- When the Legal Procedures page loads, it automatically performs a notification check
- This ensures notifications work even if background tasks are unavailable
- Users can also manually trigger checks using the bell icon in the app bar

### 4. Notification Logic
- The system checks if `statusUpdatedAt` is more than 1 hour ago
- If a procedure is overdue AND no notification has been sent yet (`overdueNotificationSent` is false)
- A local notification is shown to the user
- The `overdueNotificationSent` flag is set to `true` to prevent duplicate notifications

### 5. Error Handling
- The system gracefully handles platforms where WorkManager is not supported
- App initialization continues even if notification setup fails
- Manual notification checks are always available as a fallback

## Database Structure
The `user_procedures` collection now includes these fields:
- `status`: "Not Started", "In Progress", or "Completed"
- `statusUpdatedAt`: Timestamp when status last changed
- `overdueNotificationSent`: Boolean flag to prevent duplicate notifications
- `procedureName`: Name of the procedure for the notification

## Permissions
The system requires these Android permissions:
- `POST_NOTIFICATIONS`: To show notifications
- `WAKE_LOCK`: For background processing
- `FOREGROUND_SERVICE`: For background tasks
- `RECEIVE_BOOT_COMPLETED`: To restart background tasks after device reboot

## Files Modified
1. `pubspec.yaml` - Added flutter_local_notifications and workmanager dependencies
2. `lib/main.dart` - Initialize notification service on app startup
3. `lib/services/notification_service.dart` - Core notification logic
4. `lib/screens/Procedure_detail_page.dart` - Status tracking when steps are completed
5. `lib/screens/legal_procedures_page.dart` - Manual notification check button
6. `android/app/src/main/AndroidManifest.xml` - Added required permissions and services

## Usage
1. Start a procedure and complete at least one step
2. Wait for more than 1 hour (or use the manual check button for testing)
3. A notification will appear saying the procedure is overdue
4. Only one notification will be sent per procedure until the status changes again

**Note**: Background tasks work best on Android devices. On other platforms (like web), the system relies on manual checks when the app is opened or when the user clicks the notification bell icon.
