import 'package:flutter/material.dart';
import 'package:lawlink/services/firebase_chat_storage_service.dart';

class ConversationListPage extends StatefulWidget {
  final Function(String id, String title)? onConversationSelected;

  const ConversationListPage({Key? key, this.onConversationSelected})
    : super(key: key);

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  final FirebaseChatStorageService _chatStorageService =
      FirebaseChatStorageService();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final conversations = await _chatStorageService.getConversations();
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversations: $e')),
      );
    }
  }

  Future<void> _deleteConversation(String id) async {
    try {
      await _chatStorageService.deleteConversation(id);
      await _loadConversations();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Conversation deleted')));
    } catch (e) {
      print('Error deleting conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete conversation: $e')),
      );
    }
  }

  void _showRenameDialog(String id, String currentTitle) {
    final TextEditingController titleController = TextEditingController(
      text: currentTitle,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Rename Conversation',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Conversation Title',
                hintText: 'Enter a title for this conversation',
                labelStyle: TextStyle(color: Colors.blue.shade700),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade500),
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newTitle = titleController.text.trim();
                  if (newTitle.isNotEmpty) {
                    try {
                      await _chatStorageService.updateConversationTitle(
                        id,
                        newTitle,
                      );
                      await _loadConversations();
                    } catch (e) {
                      print('Error renaming conversation: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to rename conversation: $e'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
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
            centerTitle: false,
            iconTheme: IconThemeData(color: Colors.blue.shade700),
            title: ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
              child: const Text(
                'Conversation History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
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
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.blue.shade700),
                onPressed: _loadConversations,
                tooltip: 'Refresh',
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
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue[700]!,
                    ),
                  ),
                )
                : _conversations.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 72,
                          color: Colors.blue.shade300,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Start chatting to create a new conversation',
                        style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('New Conversation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(context, {'action': 'new'});
                        },
                      ),
                    ],
                  ),
                )
                : Padding(
                  // Padding for the entire list view container
                  padding: EdgeInsets.only(
                    // Add top padding to account for app bar + safe area
                    top: MediaQuery.of(context).padding.top - 24,
                  ),
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    // Horizontal padding for individual list items
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      // We're not using created date right now, so we can remove it
                      final DateTime updated =
                          DateTime.fromMillisecondsSinceEpoch(
                            conversation['updated_at'] ?? 0,
                          );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Dismissible(
                          key: Key(conversation['id']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.shade200.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(
                              Icons.delete,
                              color: Colors.red.shade700,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Text(
                                      'Delete Conversation',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: const Text(
                                      'Are you sure you want to delete this conversation? This action cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                          onDismissed: (direction) {
                            _deleteConversation(conversation['id']);
                          },
                          child: Card(
                            elevation: 2,
                            shadowColor: Colors.blue.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.blue.shade200.withOpacity(0.5),
                                width: 0.5,
                              ),
                            ),
                            // Add a subtle gradient overlay
                            clipBehavior: Clip.antiAlias,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: [
                                    Colors.white,
                                    Colors.blue.shade50.withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical:
                                      10, // Slightly increase vertical padding
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade700,
                                        Colors.blue.shade400,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade300.withOpacity(
                                          0.4,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: const CircleAvatar(
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.chat,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  conversation['title'] ??
                                      'Untitled Conversation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade800,
                                    fontSize: 16,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 10,
                                            color: Colors.blue.shade400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDate(updated),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: PopupMenuButton(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                    elevation: 4,
                                    offset: const Offset(0, 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Colors.blue.shade100,
                                        width: 0.5,
                                      ),
                                    ),
                                    color: Colors.white,
                                    itemBuilder:
                                        (context) => [
                                          PopupMenuItem(
                                            value: 'rename',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit,
                                                  size: 20,
                                                  color: Colors.blue.shade700,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Rename',
                                                  style: TextStyle(
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  size: 20,
                                                  color: Colors.red.shade700,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        _showRenameDialog(
                                          conversation['id'],
                                          conversation['title'] ??
                                              'Untitled Conversation',
                                        );
                                      } else if (value == 'delete') {
                                        _deleteConversation(conversation['id']);
                                      }
                                    },
                                  ),
                                ),
                                onTap: () {
                                  if (widget.onConversationSelected != null) {
                                    widget.onConversationSelected!(
                                      conversation['id'],
                                      conversation['title'] ??
                                          'Untitled Conversation',
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
      floatingActionButton:
          _conversations.isNotEmpty
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.pop(context, {'action': 'new'});
                },
                backgroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.shade100, width: 1),
                ),
                child: Icon(Icons.add, color: Colors.blue.shade600),
              )
              : null,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}
