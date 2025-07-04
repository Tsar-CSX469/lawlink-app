import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lawlink/services/auth_service.dart';
import 'package:lawlink/screens/user_profile_page.dart';
import 'package:lawlink/screens/chatbot_page.dart';
import 'package:lawlink/screens/legal_procedures_page.dart';
import 'package:lawlink/screens/settings_page.dart';
import 'package:lawlink/act_list_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final AuthService _authService = AuthService();
  String _userName = 'User';
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      User? user = _authService.currentUser;

      if (user != null) {
        // Use display name if available, otherwise use email
        setState(() {
          _userName =
              user.displayName?.split(' ')[0] ??
              user.email?.split('@')[0] ??
              'User';
          _profileImageUrl = user.photoURL;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Get the time of day for the greeting
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = l10n.goodMorning;
    } else if (hour < 17) {
      greeting = l10n.goodAfternoon;
    } else {
      greeting = l10n.goodEvening;
    }
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
            // Explicitly disable back arrow for the main screen
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo without name
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Image.asset(
                    'assets/images/logo-without-name.png',
                    height: 28,
                  ),
                ),
                // App Title
                ShaderMask(
                  shaderCallback:
                      (bounds) => LinearGradient(
                        colors: [Colors.blue.shade800, Colors.blue.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                  child: const Text(
                    'LawLink',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            actions: [
              // Light/Dark mode toggle
              IconButton(
                icon: Icon(Icons.light_mode, color: Colors.blue.shade700),
                tooltip: l10n.toggleDarkMode,
                onPressed: () {
                  // Show Coming Soon alert
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: Text(
                            l10n.comingSoon,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(l10n.darkModeComingSoon),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                l10n.ok,
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                  );
                },
              ),

              // Profile icon button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserProfilePage(),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage:
                        _profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : null,
                    child:
                        _profileImageUrl == null
                            ? Text(
                              _userName[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            )
                            : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.blue.shade50],
                    stops: const [0.7, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      // Main content
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Simplified welcome banner with light white/blue gradient
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 15),
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.white, Colors.blue.shade50],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.blue.shade100,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Greeting text
                                  ShaderMask(
                                    shaderCallback:
                                        (bounds) => LinearGradient(
                                          colors: [
                                            Colors.blue.shade800,
                                            Colors.blue.shade300,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(bounds),
                                    child: Text(
                                      greeting,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      ShaderMask(
                                        shaderCallback:
                                            (bounds) => LinearGradient(
                                              colors: [
                                                Colors.blue.shade800,
                                                Colors.blue.shade300,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ).createShader(bounds),
                                        child: Text(
                                          _userName,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.waving_hand_rounded,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  Divider(
                                    color: Colors.blue.shade200.withOpacity(
                                      0.3,
                                    ),
                                    thickness: 0.5,
                                  ),
                                  const SizedBox(height: 8),

                                  // Simple welcome text
                                  Text(
                                    l10n.welcomeToApp,
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 25),

                            // Services title
                            Row(
                              children: [
                                Icon(
                                  Icons.grid_view_rounded,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.services,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Feature cards
                            Expanded(
                              child: GridView.count(
                                padding: EdgeInsets.zero,
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.05,
                                children: [
                                  // Quiz Game Card
                                  _buildFeatureCard(
                                    title: l10n.quiz,
                                    icon: Icons.lightbulb_outline,
                                    color: Colors.blue.shade700,
                                    onTap: () {
                                      Navigator.pushNamed(context, '/quiz');
                                    },
                                  ), // LawLink AI Card
                                  _buildFeatureCard(
                                    title: l10n.lawlinkAi,
                                    icon: Icons.bubble_chart_rounded,
                                    color: Colors.blue.shade700,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => const ChatbotPage(),
                                        ),
                                      );
                                    },
                                  ),

                                  // Procedures Card
                                  _buildFeatureCard(
                                    title: l10n.procedures,
                                    icon: Icons.assignment_outlined,
                                    color: Colors.blue.shade700,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const LegalProceduresPage(),
                                        ),
                                      );
                                    },
                                  ),

                                  // Law Library Card
                                  _buildFeatureCard(
                                    title: l10n.acts,
                                    icon: Icons.menu_book_rounded,
                                    color: Colors.blue.shade700,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => const ActListPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Settings button at the bottom left
                      Positioned(
                        left: 20,
                        bottom: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.settings_outlined,
                              color: Colors.blue.shade700,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
                            tooltip: l10n.settings,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
