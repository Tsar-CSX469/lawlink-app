import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  DocumentSnapshot? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = _authService.currentUser;
    if (_currentUser != null) {
      try {
        _userData = await _authService.getUserData(_currentUser!.uid);
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.blue.shade50],
              stops: const [0.7, 1.0],
            ),
          ),
          child: const Center(
            child: Text(
              'No user logged in',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final userData = _userData?.data() as Map<String, dynamic>?;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 15,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: AppBar(
            title: ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
              child: const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.blue.shade700),
            actions: [              // Light/Dark mode toggle
              IconButton(
                icon: const Icon(Icons.light_mode),
                color: Colors.blue.shade700, // Ensure consistent blue color
                tooltip: 'Toggle Light Mode',
                onPressed: () {
                  // Show Coming Soon alert
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: Text(
                            'Coming Soon!',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: const Text(
                            'Dark mode functionality will be available in the next update!',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'OK',
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      await _authService.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
            stops: const [0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile header with avatar
                Card(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  color: Colors.white,
                  // shape: RoundedRectangleBorder(
                  //   borderRadius: BorderRadius.circular(16),
                  //   side: BorderSide(color: Colors.blue.shade100, width: 1),
                  // ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 50,
                            // backgroundColor: Colors.blue.shade50,
                            backgroundImage:
                                _currentUser!.photoURL != null
                                    ? NetworkImage(_currentUser!.photoURL!)
                                    : null,
                            child:
                                _currentUser!.photoURL == null
                                    ? Text(
                                      _currentUser!.displayName
                                              ?.substring(0, 1)
                                              .toUpperCase() ??
                                          _currentUser!.email
                                              ?.substring(0, 1)
                                              .toUpperCase() ??
                                          'U',
                                      style: TextStyle(
                                        fontSize: 36,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentUser!.displayName ??
                              userData?['username'] ??
                              'User',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser!.email ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _currentUser!.emailVerified
                                  ? Icons.verified_user
                                  : Icons.warning,
                              size: 16,
                              color:
                                  _currentUser!.emailVerified
                                      ? const Color.fromARGB(255, 48, 114, 51)
                                      : Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentUser!.emailVerified
                                  ? 'Verified Account'
                                  : 'Email not verified',
                              style: TextStyle(
                                color:
                                    _currentUser!.emailVerified
                                        ? const Color.fromARGB(255, 48, 114, 51)
                                        : Colors.amber,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Account Information Card
                Card(
                  elevation: 4,
                  shadowColor: Colors.blue.withOpacity(0.1),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blue.shade100, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Account Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          label: 'Name',
                          value:
                              _currentUser!.displayName ??
                              userData?['username'] ??
                              'Not set',
                          icon: Icons.person_outline,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          label: 'Email',
                          value: _currentUser!.email ?? 'Not set',
                          icon: Icons.email_outlined,
                        ),
                        if (userData?['createdAt'] != null) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            label: 'Member Since',
                            value: _formatDate(userData!['createdAt']),
                            icon: Icons.calendar_today_outlined,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Security Information
                Card(
                  elevation: 4,
                  shadowColor: Colors.blue.withOpacity(0.1),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blue.shade100, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Security',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Icon(
                            Icons.lock_outline,
                            color: Colors.blue.shade400,
                          ),
                          title: const Text('Change Password'),
                          trailing: const Icon(Icons.chevron_right),
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            // Implement password change functionality
                            _showFeatureComingSoonDialog(context);
                          },
                        ),
                        const Divider(height: 16),
                        ListTile(
                          leading: Icon(
                            Icons.verified_user_outlined,
                            color: Colors.blue.shade400,
                          ),
                          title: const Text('Two-Factor Authentication'),
                          trailing: const Icon(Icons.chevron_right),
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            // Implement 2FA functionality
                            _showFeatureComingSoonDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ), // Logout button is now in the app bar

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.blue.shade400),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Invalid date';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  void _showFeatureComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Coming Soon',
              style: TextStyle(color: Colors.blue.shade700),
            ),
            content: const Text(
              'This feature will be available in a future update.',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
    );
  }
}
