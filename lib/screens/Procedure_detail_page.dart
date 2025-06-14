import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProcedureDetailPage extends StatefulWidget {
  final String procedureId;
  final Map<String, dynamic> procedureData;

  const ProcedureDetailPage({
    Key? key,
    required this.procedureId,
    required this.procedureData,
  }) : super(key: key);

  @override
  State<ProcedureDetailPage> createState() => _ProcedureDetailPageState();
}

class _ProcedureDetailPageState extends State<ProcedureDetailPage> {
  List<int> completedSteps = [];
  List<Map<String, dynamic>> comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_procedures')
          .doc('${user.uid}_${widget.procedureId}')
          .get();
      
      if (doc.exists && mounted) {
        setState(() {
          completedSteps = List<int>.from(doc.data()?['completedSteps'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading progress: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('procedures')
          .doc(widget.procedureId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          comments = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'comment': data['comment'] ?? '',
              'userId': data['userId'] ?? '',
              'timestamp': data['timestamp'],
              'userEmail': data['userEmail'] ?? 'Unknown User',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _toggleStepCompletion(int stepIndex, bool isCompleted) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (isCompleted) {
        if (!completedSteps.contains(stepIndex)) {
          completedSteps.add(stepIndex);
        }
      } else {
        completedSteps.remove(stepIndex);
      }
    });

    try {
      await FirebaseFirestore.instance
          .collection('user_procedures')
          .doc('${user.uid}_${widget.procedureId}')
          .set({
        'userId': user.uid,
        'procedureId': widget.procedureId,
        'completedSteps': completedSteps,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving progress: $e');
      // Revert the UI change if save failed
      setState(() {
        if (isCompleted) {
          completedSteps.remove(stepIndex);
        } else {
          completedSteps.add(stepIndex);
        }
      });
    }
  }

  Future<void> _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _commentController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('procedures')
          .doc(widget.procedureId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'userEmail': user.email ?? 'Unknown User',
        'comment': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      await _loadComments(); // Refresh comments
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully')),
        );
      }
    } catch (e) {
      print('Error submitting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add comment')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('procedures')
          .doc(widget.procedureId)
          .collection('comments')
          .doc(commentId)
          .delete();

      await _loadComments(); // Refresh comments

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete comment')),
        );
      }
    }
  }

  void _showDeleteCommentDialog(String commentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Comment'),
          content: const Text('Are you sure you want to delete this comment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteComment(commentId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> steps = widget.procedureData['steps'] ?? [];
    final List<dynamic> prerequisites = widget.procedureData['prerequisites'] ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.procedureData['title'] ?? 'Procedure'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            if (widget.procedureData['description'] != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.procedureData['description'],
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Prerequisites
            if (prerequisites.isNotEmpty) ...[
              const Text(
                'Prerequisites:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: prerequisites
                        .map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(child: Text(item.toString())),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Steps
            const Text(
              'Steps:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            if (steps.isNotEmpty)
              Card(
                child: Column(
                  children: steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value.toString();
                    final isCompleted = completedSteps.contains(index);
                    
                    return CheckboxListTile(
                      title: Text(
                        step,
                        style: TextStyle(
                          decoration: isCompleted 
                              ? TextDecoration.lineThrough 
                              : TextDecoration.none,
                          color: isCompleted 
                              ? Colors.grey 
                              : null,
                        ),
                      ),
                      value: isCompleted,
                      onChanged: (value) => _toggleStepCompletion(index, value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Progress indicator
            if (steps.isNotEmpty) ...[
              Text(
                'Progress: ${completedSteps.length}/${steps.length} steps completed',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: steps.isEmpty ? 0 : completedSteps.length / steps.length,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  completedSteps.length == steps.length 
                      ? Colors.green 
                      : Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Comments section
            const Divider(),
            const Text(
              'Comments:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            // Add comment
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'Add a comment...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitComment,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Submit Comment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Display comments
            if (comments.isNotEmpty)
              ...comments.map((comment) {
                final currentUser = FirebaseAuth.instance.currentUser;
                final isCurrentUserComment = currentUser?.uid == comment['userId'];
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: const Icon(Icons.comment),
                    title: Text(comment['comment']),
                    subtitle: Text(
                      'By: ${comment['userEmail']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isCurrentUserComment
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteCommentDialog(comment['id']),
                            tooltip: 'Delete comment',
                          )
                        : null,
                  ),
                );
              })
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('No comments yet'),
                  subtitle: Text('Be the first to add a comment!'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}