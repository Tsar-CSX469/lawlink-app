import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<LeaderboardEntry> _allEntries = [];
  bool _isLoading = true;
  String? _error;

  // Quiz categories for tabs
  final List<QuizCategory> _quizCategories = [
    QuizCategory(id: 'all', name: 'Overall', icon: Icons.leaderboard),
    QuizCategory(
      id: 'consumer_affairs_quiz',
      name: 'Consumer Law',
      icon: Icons.shopping_cart,
    ),
    QuizCategory(
      id: 'criminal_law_quiz',
      name: 'Criminal Law',
      icon: Icons.gavel,
    ),
    QuizCategory(id: 'civil_law_quiz', name: 'Civil Law', icon: Icons.balance),
    QuizCategory(
      id: 'employment_law_quiz',
      name: 'Employment Law',
      icon: Icons.work,
    ),
    QuizCategory(
      id: 'family_law_quiz',
      name: 'Family Law',
      icon: Icons.family_restroom,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _quizCategories.length, vsync: this);
    _fetchLeaderboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaderboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch all quiz results from Firestore
      QuerySnapshot querySnapshot =
          await _firestore
              .collection('scores')
              .orderBy('completedAt', descending: true)
              .limit(200) // Increased limit for more comprehensive data
              .get();

      List<LeaderboardEntry> entries = [];
      Map<String, String> userNamesCache = {};

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        String userId = data['userId'] ?? '';
        String userName = 'Anonymous User';

        // Try to get username from cache first
        if (userNamesCache.containsKey(userId)) {
          userName = userNamesCache[userId]!;
        } else if (userId.isNotEmpty) {
          // Fetch username from users collection
          try {
            DocumentSnapshot userDoc =
                await _firestore.collection('users').doc(userId).get();

            if (userDoc.exists) {
              Map<String, dynamic>? userData =
                  userDoc.data() as Map<String, dynamic>?;
              userName =
                  userData?['name'] ??
                  userData?['displayName'] ??
                  userData?['username'] ??
                  'User ${userId.substring(0, 6)}';
              userNamesCache[userId] = userName;
            } else {
              userName = 'User ${userId.substring(0, 6)}';
              userNamesCache[userId] = userName;
            }
          } catch (e) {
            userName = 'User ${userId.substring(0, 6)}';
            userNamesCache[userId] = userName;
          }
        }

        LeaderboardEntry entry = LeaderboardEntry(
          userId: userId,
          userName: userName,
          score: data['score'] ?? 0,
          total: data['total'] ?? 0,
          quizId: data['quizId'] ?? '',
          completedAt:
              (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );

        entries.add(entry);
      }

      setState(() {
        _allEntries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load leaderboard: $e';
        _isLoading = false;
      });
      print('Error fetching leaderboard data: $e');
    }
  }

  List<LeaderboardEntry> getSortedEntries({String? quizFilter}) {
    List<LeaderboardEntry> entries = List.from(_allEntries);

    // Filter by quiz if specified
    if (quizFilter != null && quizFilter != 'all') {
      entries = entries.where((entry) => entry.quizId == quizFilter).toList();
    }

    // Group by user and quiz, keeping only the best score for each user per quiz
    Map<String, LeaderboardEntry> bestScores = {};

    for (LeaderboardEntry entry in entries) {
      String key =
          quizFilter == 'all'
              ? '${entry.userId}_${entry.quizId}'
              : entry.userId;

      if (!bestScores.containsKey(key) ||
          (entry.score / entry.total) >
              (bestScores[key]!.score / bestScores[key]!.total)) {
        bestScores[key] = entry;
      }
    }

    List<LeaderboardEntry> uniqueEntries = bestScores.values.toList();

    // Sort by percentage, then by completion time
    uniqueEntries.sort((a, b) {
      double percentageA = (a.score / a.total) * 100;
      double percentageB = (b.score / b.total) * 100;

      if (percentageA != percentageB) {
        return percentageB.compareTo(percentageA);
      }
      return a.completedAt.compareTo(b.completedAt);
    });

    return uniqueEntries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Leaderboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade400, Colors.purple.shade400],
            ),
          ),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            height: 50,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs:
                  _quizCategories
                      .map(
                        (category) => Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(category.icon, size: 16),
                              const SizedBox(width: 4),
                              Text(category.name),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
            stops: const [0.0, 0.3],
          ),
        ),
        child:
            _isLoading
                ? _buildLoadingState()
                : _error != null
                ? _buildErrorState()
                : TabBarView(
                  controller: _tabController,
                  children:
                      _quizCategories
                          .map(
                            (category) =>
                                _buildLeaderboardList(quizFilter: category.id),
                          )
                          .toList(),
                ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading leaderboard...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 16, color: Colors.red.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchLeaderboardData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList({String? quizFilter}) {
    List<LeaderboardEntry> entries = getSortedEntries(quizFilter: quizFilter);

    if (entries.isEmpty) {
      return _buildEmptyState(quizFilter);
    }

    return RefreshIndicator(
      onRefresh: _fetchLeaderboardData,
      color: Colors.blue.shade400,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildPodium(entries);
          }

          final entry = entries[index - 1];
          return _buildLeaderboardItem(entry, index);
        },
      ),
    );
  }

  // Complete fixes for all overflow issues

  // 1. Fixed _buildPodium method
  Widget _buildPodium(List<LeaderboardEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '🏆 Champions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          SizedBox(
            height: 350, // Increased height significantly
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                double availableWidth = constraints.maxWidth;
                double cardWidth =
                    (availableWidth - 60) / 3; // Account for padding
                cardWidth = cardWidth.clamp(80.0, 120.0); // Min/Max width

                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Podium bases
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (entries.length >= 2)
                          _buildPodiumBase(
                            120,
                            Colors.grey.shade300,
                            '2',
                            cardWidth,
                          ),
                        if (entries.isNotEmpty)
                          _buildPodiumBase(
                            160,
                            Colors.amber.shade300,
                            '1',
                            cardWidth,
                          ),
                        if (entries.length >= 3)
                          _buildPodiumBase(
                            100,
                            Colors.brown.shade300,
                            '3',
                            cardWidth,
                          ),
                      ],
                    ),
                    // Winners
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (entries.length >= 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 140),
                            child: _buildWinnerCard(entries[1], 2, cardWidth),
                          ),
                        if (entries.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 180),
                            child: _buildWinnerCard(entries[0], 1, cardWidth),
                          ),
                        if (entries.length >= 3)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 120),
                            child: _buildWinnerCard(entries[2], 3, cardWidth),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 2. Fixed _buildPodiumBase method with dynamic width
  Widget _buildPodiumBase(
    double height,
    Color color,
    String position,
    double width,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          position,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // 3. Fixed _buildWinnerCard method with dynamic width and better overflow handling
  Widget _buildWinnerCard(
    LeaderboardEntry entry,
    int position,
    double cardWidth,
  ) {
    Color primaryColor;
    Color secondaryColor;
    IconData crownIcon;

    switch (position) {
      case 1:
        primaryColor = Colors.amber.shade400;
        secondaryColor = Colors.amber.shade100;
        crownIcon = Icons.emoji_events;
        break;
      case 2:
        primaryColor = Colors.grey.shade400;
        secondaryColor = Colors.grey.shade100;
        crownIcon = Icons.workspace_premium;
        break;
      case 3:
        primaryColor = Colors.brown.shade400;
        secondaryColor = Colors.brown.shade100;
        crownIcon = Icons.military_tech;
        break;
      default:
        primaryColor = Colors.grey.shade400;
        secondaryColor = Colors.grey.shade100;
        crownIcon = Icons.star;
    }

    double percentage = (entry.score / entry.total) * 100;
    bool isCurrentUser = _auth.currentUser?.uid == entry.userId;

    return SizedBox(
      width: cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown/Medal
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(crownIcon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 4),
          // User Avatar
          Container(
            width: cardWidth * 0.6, // Responsive avatar size
            height: cardWidth * 0.6,
            decoration: BoxDecoration(
              color: secondaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrentUser ? Colors.blue.shade400 : primaryColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                entry.userName.isNotEmpty
                    ? entry.userName[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: cardWidth * 0.25, // Responsive font size
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // User Name - Fixed overflow
          Container(
            width: cardWidth,
            child: Text(
              entry.userName.length > 8
                  ? '${entry.userName.substring(0, 8)}...'
                  : entry.userName,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          // Score
          Text(
            '${percentage.toStringAsFixed(0)}%', // Removed decimal for space
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'You',
                style: TextStyle(
                  fontSize: 6,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 4. Fixed _buildLeaderboardItem method for horizontal overflow
  Widget _buildLeaderboardItem(LeaderboardEntry entry, int rank) {
    double percentage = (entry.score / entry.total) * 100;
    bool isCurrentUser = _auth.currentUser?.uid == entry.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            isCurrentUser
                ? Border.all(color: Colors.blue.shade300, width: 2)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Rank circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getRankColor(rank).withOpacity(0.8),
                    _getRankColor(rank).withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Main content - Fixed overflow
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and "You" badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color:
                                isCurrentUser
                                    ? Colors.blue.shade700
                                    : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'You',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Score and category info - Fixed overflow
                  Row(
                    children: [
                      Icon(Icons.quiz, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 3),
                      Text(
                        '${entry.score}/${entry.total}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.category,
                        size: 12,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          _getQuizDisplayName(entry.quizId),
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Time info
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          _formatDate(entry.completedAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getScoreColor(percentage),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Score percentage - Fixed size
            SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _getScoreColor(percentage),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    _getScoreIcon(percentage),
                    color: _getScoreColor(percentage),
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String? quizFilter) {
    String categoryName =
        _quizCategories
            .firstWhere(
              (cat) => cat.id == quizFilter,
              orElse:
                  () => QuizCategory(
                    id: 'all',
                    name: 'Overall',
                    icon: Icons.leaderboard,
                  ),
            )
            .name;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard_outlined,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'No $categoryName scores yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Complete some ${categoryName.toLowerCase()} quizzes to see your ranking!',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to quiz selection or start a quiz
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank <= 3) return Colors.amber.shade600;
    if (rank <= 10) return Colors.blue.shade600;
    if (rank <= 20) return Colors.green.shade600;
    return Colors.grey.shade600;
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 90) return Colors.green.shade600;
    if (percentage >= 75) return Colors.orange.shade600;
    if (percentage >= 60) return Colors.amber.shade600;
    return Colors.red.shade600;
  }

  IconData _getScoreIcon(double percentage) {
    if (percentage >= 90) return Icons.star;
    if (percentage >= 75) return Icons.thumb_up;
    if (percentage >= 60) return Icons.trending_up;
    return Icons.trending_down;
  }

  String _getQuizDisplayName(String quizId) {
    switch (quizId) {
      case 'consumer_affairs_quiz':
        return 'Consumer Law';
      case 'criminal_law_quiz':
        return 'Criminal Law';
      case 'civil_law_quiz':
        return 'Civil Law';
      case 'employment_law_quiz':
        return 'Employment Law';
      case 'family_law_quiz':
        return 'Family Law';
      case 'constitutional_law_quiz':
        return 'Constitutional Law';
      case 'property_law_quiz':
        return 'Property Law';
      default:
        return 'General Quiz';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

class LeaderboardEntry {
  final String userId;
  final String userName;
  final int score;
  final int total;
  final String quizId;
  final DateTime completedAt;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.score,
    required this.total,
    required this.quizId,
    required this.completedAt,
  });

  factory LeaderboardEntry.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    return LeaderboardEntry(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous User',
      score: data['score'] ?? 0,
      total: data['total'] ?? 0,
      quizId: data['quizId'] ?? '',
      completedAt:
          (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class QuizCategory {
  final String id;
  final String name;
  final IconData icon;

  QuizCategory({required this.id, required this.name, required this.icon});
}
