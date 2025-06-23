import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lawlink/screens/procedure_detail_page.dart';

class LegalProceduresPage extends StatefulWidget {
  const LegalProceduresPage({Key? key}) : super(key: key);

  @override
  State<LegalProceduresPage> createState() => _LegalProceduresPageState();
}

class _LegalProceduresPageState extends State<LegalProceduresPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('legal_procedures').get();

      final categories = <String>{'All'};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['category'] != null) {
          categories.add(data['category'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _categories = categories.toList()..sort();
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<String> _getProcedureStatus(String procedureId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Not Started';

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('user_procedures')
              .doc('${user.uid}_$procedureId')
              .get();

      if (!doc.exists) return 'Not Started';

      final completedSteps = List<int>.from(
        doc.data()?['completedSteps'] ?? [],
      );

      final procedureDoc =
          await FirebaseFirestore.instance
              .collection('legal_procedures')
              .doc(procedureId)
              .get();

      if (!procedureDoc.exists) return 'Not Started';

      final totalSteps = (procedureDoc.data()?['steps'] as List?)?.length ?? 0;

      if (completedSteps.isEmpty) return 'Not Started';
      if (completedSteps.length == totalSteps) return 'Completed';
      return 'In Progress';
    } catch (e) {
      return 'Not Started';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Not Started':
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'In Progress':
        return Icons.hourglass_empty;
      case 'Not Started':
      default:
        return Icons.radio_button_unchecked;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'traffic':
        return Icons.traffic;
      case 'business':
        return Icons.business;
      case 'property':
        return Icons.home;
      case 'marriage':
        return Icons.favorite;
      case 'consumer':
        return Icons.receipt_long;
      case 'court':
        return Icons.gavel;
      default:
        return Icons.description;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'traffic':
        return Colors.red;
      case 'business':
        return Colors.orange;
      case 'property':
        return Colors.blue.shade700;
      case 'marriage':
        return Colors.pink;
      case 'consumer':
        return Colors.green;
      case 'court':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;

    final title = (data['title'] ?? '').toString().toLowerCase();
    final description = (data['description'] ?? '').toString().toLowerCase();
    final category = (data['category'] ?? '').toString().toLowerCase();
    final query = _searchQuery.toLowerCase();

    return title.contains(query) ||
        description.contains(query) ||
        category.contains(query);
  }

  bool _matchesCategory(Map<String, dynamic> data) {
    if (_selectedCategory == 'All') return true;
    return (data['category'] ?? '').toString() == _selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            title: ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
              child: const Text(
                'Legal Procedures',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
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
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search procedures...',
                    prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8), // Category filters
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color:
                              isSelected
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade700,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Procedures list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('legal_procedures')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading procedures',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No legal procedures found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for updates',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs =
                      snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _matchesSearch(data) && _matchesCategory(data);
                      }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No procedures found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final category = data['category'] ?? '';
                      final estimatedTime = data['estimated_time'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 4,
                          shadowColor: Colors.blue.withOpacity(0.2),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Colors.blue.shade100,
                              width: 1,
                            ),
                          ),
                          child: FutureBuilder<String>(
                            future: _getProcedureStatus(doc.id),
                            builder: (context, statusSnapshot) {
                              final status =
                                  statusSnapshot.data ?? 'Not Started';
                              final statusColor = _getStatusColor(status);
                              final statusIcon = _getStatusIcon(status);
                              final categoryColor = _getCategoryColor(category);
                              final categoryIcon = _getCategoryIcon(category);

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => ProcedureDetailPage(
                                            procedureId: doc.id,
                                            procedureData: data,
                                          ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: categoryColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              categoryIcon,
                                              color: categoryColor,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  data['title'] ?? 'No title',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (category.isNotEmpty)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: categoryColor
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      category,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: categoryColor,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        data['description'] ?? 'No description',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  statusIcon,
                                                  size: 14,
                                                  color: statusColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (estimatedTime.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.access_time,
                                                    size: 14,
                                                    color: Colors.blue,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    estimatedTime,
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
