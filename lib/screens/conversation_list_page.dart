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
            title: const Text('Rename Conversation'),
            content: TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Conversation Title',
                hintText: 'Enter a title for this conversation',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
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
                        ),
                      );
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 72,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No conversations yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start chatting to create a new conversation',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('New Conversation'),
                      onPressed: () {
                        Navigator.pop(context, {'action': 'new'});
                      },
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  final DateTime created = DateTime.fromMillisecondsSinceEpoch(
                    conversation['created_at'] ?? 0,
                  );
                  final DateTime updated = DateTime.fromMillisecondsSinceEpoch(
                    conversation['updated_at'] ?? 0,
                  );

                  return Dismissible(
                    key: Key(conversation['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Delete Conversation'),
                              content: const Text(
                                'Are you sure you want to delete this conversation? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                    onDismissed: (direction) {
                      _deleteConversation(conversation['id']);
                    },
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.chat, color: Colors.white),
                      ),
                      title: Text(
                        conversation['title'] ?? 'Untitled Conversation',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Updated: ${_formatDate(updated)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('Rename'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                        onSelected: (value) {
                          if (value == 'rename') {
                            _showRenameDialog(
                              conversation['id'],
                              conversation['title'] ?? 'Untitled Conversation',
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
                            conversation['title'] ?? 'Untitled Conversation',
                          );
                          Navigator.pop(context);
                        }
                      },
                    ),
                  );
                },
              ),
      floatingActionButton:
          _conversations.isNotEmpty
              ? FloatingActionButton(
                onPressed: () {
                  Navigator.pop(context, {'action': 'new'});
                },
                backgroundColor: Colors.blue,
                child: const Icon(Icons.add),
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
