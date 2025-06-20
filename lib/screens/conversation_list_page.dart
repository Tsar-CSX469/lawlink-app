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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.blue.shade700),
        title: Text(
          'Conversations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.blue.shade700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 22, color: Colors.blue.shade600),
            onPressed: _loadConversations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50.withOpacity(0.7)],
            stops: const [0.8, 1.0],
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 40,
                          color: Colors.blue.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting to create a new conversation',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Conversation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 14),
                          elevation: 0,
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
                            elevation: 0.5,
                            shadowColor: Colors.black.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: Colors.grey.shade200,
                                width: 0.5,
                              ),
                            ),
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Icon(
                                Icons.chat_outlined,
                                color: Colors.blue.shade400,
                                size: 22,
                              ),
                              title: Text(
                                conversation['title'] ??
                                    'Untitled Conversation',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatDate(updated),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: PopupMenuButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                elevation: 2,
                                offset: const Offset(0, 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                                              size: 18,
                                              color: Colors.grey.shade800,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('Rename'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 18,
                                              color: Colors.red.shade400,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red.shade400,
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
                backgroundColor: Colors.blue.shade600,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add, color: Colors.white),
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
