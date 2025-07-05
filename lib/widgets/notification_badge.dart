import 'package:flutter/material.dart';
import 'dart:async';
import '../services/enhanced_notification_service.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const NotificationBadge({super.key, required this.child, this.onTap});

  @override
  State<NotificationBadge> createState() => NotificationBadgeState();
}

class NotificationBadgeState extends State<NotificationBadge> {
  bool _hasUnreadNotifications = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUnreadStatus();
    // Refresh every 5 seconds to keep badge updated quickly
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadUnreadStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadStatus() async {
    try {
      final count = await NotificationService.getUnreadNotificationCount();
      if (mounted) {
        setState(() {
          _hasUnreadNotifications = count > 0;
        });
      }
    } catch (e) {
      print('Error loading unread status: $e');
    }
  }

  // Method to refresh the badge from parent widgets
  void refresh() {
    _loadUnreadStatus();
  }

  // Method to force immediate refresh (for when returning from notifications page)
  void forceRefresh() {
    _loadUnreadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_hasUnreadNotifications)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
