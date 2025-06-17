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
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110), // Height for app bar + tabs
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 15,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                centerTitle: true,
                title: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    '🏆 Leaderboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: Colors.blue.shade500,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: _quizCategories.map((category) => Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(category.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: _isLoading 
              ? _buildLoadingState()
              : _error != null
                  ? _buildErrorState()
                  : TabBarView(
                      controller: _tabController,
                      children: _quizCategories
                          .map((category) => _buildLeaderboardList(quizFilter: category.id))
                          .toList(),
                    ),
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade500),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading leaderboard...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
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
          Icon(Icons.error_outline, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchLeaderboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 2,
            ),
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
      color: Colors.blue.shade500,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          80,
        ), // Added bottom padding
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

  Widget _buildPodium(List<LeaderboardEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // We'll only use top 3 entries
    final topEntries = entries.take(3).toList();
      // Use only top entries
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Simple leaderboard header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Top Rankings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          // Top 3 entries in a row
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topEntries.length,
            itemBuilder: (context, index) {
              final medalColors = [
                const Color(0xFFFFD700), // Gold
                const Color(0xFFC0C0C0), // Silver
                const Color(0xFFCD7F32), // Bronze
              ];
              
              final icons = [
                Icons.emoji_events,
                Icons.workspace_premium, 
                Icons.military_tech
              ];
              
              return _buildSimpleRankItem(
                topEntries[index], 
                index + 1,
                medalColors[index],
                icons[index]
              );
            },
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildSimpleRankItem(
    LeaderboardEntry entry, 
    int position, 
    Color medalColor,
    IconData icon
  ) {
    final percentage = (entry.score / entry.total) * 100;
    final isCurrentUser = _auth.currentUser?.uid == entry.userId;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? Colors.blue.shade200 : Colors.grey.shade100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            // Medal icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: medalColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: medalColor.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      entry.userName.isNotEmpty ? entry.userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name and score
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.score}/${entry.total} (${percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Position number
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade100,
              ),
              child: Center(
                child: Text(
                  '#$position',
                  style: TextStyle(
                    color: isCurrentUser ? Colors.blue.shade700 : Colors.grey.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardEntry entry, int rank) {
    double percentage = (entry.score / entry.total) * 100;
    bool isCurrentUser = _auth.currentUser?.uid == entry.userId;
    Color rankColor = _getRankColor(rank);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? Colors.blue.shade200 : Colors.blue.shade50,
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
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
            // Rank circle with gradient
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [rankColor, rankColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: rankColor.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Main content
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
                            fontSize: 16,
                            color:
                                isCurrentUser
                                    ? Colors.blue.shade700
                                    : Colors.blue.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            'You',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Score and category info
                  Row(
                    children: [
                      Icon(Icons.quiz, size: 14, color: Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.score}/${entry.total}',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.category,
                        size: 14,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getQuizDisplayName(entry.quizId),
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 12,
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
                        color: Colors.blue.shade400,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(entry.completedAt),
                          style: TextStyle(
                            color: Colors.blue.shade400,
                            fontSize: 11,
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
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.blue.shade50,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getScoreColor(percentage),
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Score percentage
            SizedBox(
              width: 65,
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
                  const SizedBox(height: 4),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.leaderboard_outlined,
              size: 100,
              color: Colors.blue.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No $categoryName Scores Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Complete some ${categoryName.toLowerCase()} quizzes to see your ranking!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to quiz selection or start a quiz
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start a Quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank <= 3) return Colors.blue.shade500;
    if (rank <= 10) return Colors.blue.shade400;
    if (rank <= 20) return Colors.blue.shade300;
    return Colors.blue.shade200;
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 90) return Colors.blue.shade500;
    if (percentage >= 75) return Colors.blue.shade400;
    if (percentage >= 60) return Colors.blue.shade300;
    return Colors.blue.shade200;
  }

  IconData _getScoreIcon(double percentage) {
    if (percentage >= 90) return Icons.emoji_events;
    if (percentage >= 75) return Icons.workspace_premium;
    if (percentage >= 60) return Icons.trending_up;
    return Icons.trending_flat;
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
