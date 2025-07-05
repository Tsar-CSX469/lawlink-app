import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ChatbotInitializationService {
  static bool _isInitialized = false;
  static bool _permissionsGranted = false;
  static bool _speechInitialized = false;
  static final SpeechToText _speechToText = SpeechToText();

  /// Check if the chatbot service is fully initialized
  static bool get isReady =>
      _isInitialized && _permissionsGranted && _speechInitialized;

  /// Get detailed status for debugging
  static Map<String, bool> get initializationStatus => {
    'initialized': _isInitialized,
    'permissions': _permissionsGranted,
    'speech': _speechInitialized,
  };

  /// Initialize the chatbot service in the background
  static Future<bool> initializeAsync({BuildContext? context}) async {
    if (_isInitialized) return true;

    try {
      // Step 1: Request permissions silently (no dialogs)
      await _requestPermissionsSilently();

      // Step 2: Initialize speech recognition
      await _initializeSpeechRecognition();

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Chatbot initialization failed: $e');
      return false;
    }
  }

  /// Request permissions without showing blocking dialogs
  static Future<void> _requestPermissionsSilently() async {
    try {
      // Check current permission status
      final micStatus = await Permission.microphone.status;
      final storageStatus = await Permission.storage.status;
      final cameraStatus = await Permission.camera.status;

      // Only request if not already decided
      final List<Permission> permissionsToRequest = [];

      if (!micStatus.isGranted && !micStatus.isPermanentlyDenied) {
        permissionsToRequest.add(Permission.microphone);
      }

      if (!storageStatus.isGranted && !storageStatus.isPermanentlyDenied) {
        permissionsToRequest.add(Permission.storage);
      }

      if (!cameraStatus.isGranted && !cameraStatus.isPermanentlyDenied) {
        permissionsToRequest.add(Permission.camera);
      }

      // Request only the undetermined permissions
      if (permissionsToRequest.isNotEmpty) {
        await permissionsToRequest.request();
      }

      // Check if we have at least microphone permission (most important)
      final finalMicStatus = await Permission.microphone.status;
      _permissionsGranted = finalMicStatus.isGranted;
    } catch (e) {
      print('Permission request failed: $e');
      _permissionsGranted = false;
    }
  }

  /// Initialize speech recognition
  static Future<void> _initializeSpeechRecognition() async {
    try {
      _speechInitialized = await _speechToText.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech recognition status: $status'),
      );
    } catch (e) {
      print('Speech initialization failed: $e');
      _speechInitialized = false;
    }
  }

  /// Check and handle missing permissions with user-friendly dialogs
  static Future<bool> checkAndRequestMissingPermissions(
    BuildContext context,
  ) async {
    final micStatus = await Permission.microphone.status;
    final cameraStatus = await Permission.camera.status;

    // If microphone is denied permanently, show settings dialog
    if (micStatus.isPermanentlyDenied) {
      return await _showPermissionSettingsDialog(
        context,
        'Microphone Access Needed',
        'LawLink AI needs microphone access for voice messages and speech recognition. Please enable it in app settings.',
        'microphone',
      );
    }

    // If microphone is denied (but not permanently), show request dialog
    if (micStatus.isDenied) {
      return await _showPermissionRequestDialog(
        context,
        'Enable Voice Features?',
        'Allow microphone access to use voice messages and speech-to-text features. You can skip this and use text chat only.',
        Permission.microphone,
      );
    }

    // Similar for camera (less critical)
    if (cameraStatus.isDenied && !cameraStatus.isPermanentlyDenied) {
      await _showPermissionRequestDialog(
        context,
        'Enable Camera Features?',
        'Allow camera access to upload images and documents. You can skip this and use text chat only.',
        Permission.camera,
        isOptional: true,
      );
    }

    return true;
  }

  /// Show a dialog to request permission
  static Future<bool> _showPermissionRequestDialog(
    BuildContext context,
    String title,
    String message,
    Permission permission, {
    bool isOptional = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: isOptional,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                _getPermissionIcon(permission),
                color: Colors.blue.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            if (isOptional)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Not Now',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final status = await permission.request();
                Navigator.of(context).pop(status.isGranted);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Show a dialog to open app settings for permanently denied permissions
  static Future<bool> _showPermissionSettingsDialog(
    BuildContext context,
    String title,
    String message,
    String permissionType,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.settings, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Continue Without $permissionType',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await openAppSettings();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Get appropriate icon for permission type
  static IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.microphone:
        return Icons.mic;
      case Permission.camera:
        return Icons.camera_alt;
      case Permission.storage:
        return Icons.folder;
      default:
        return Icons.security;
    }
  }

  /// Reset initialization state (for testing or troubleshooting)
  static void reset() {
    _isInitialized = false;
    _permissionsGranted = false;
    _speechInitialized = false;
  }

  /// Get user-friendly status message
  static String getStatusMessage() {
    if (isReady) {
      return 'LawLink AI is ready to help!';
    } else if (!_permissionsGranted) {
      return 'Grant permissions to enable all features';
    } else if (!_speechInitialized) {
      return 'Setting up speech recognition...';
    } else {
      return 'Initializing LawLink AI...';
    }
  }
}
