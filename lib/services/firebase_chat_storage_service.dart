import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lawlink/screens/chatbot_page.dart';

class FirebaseChatStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current user ID or generate an anonymous ID if not logged in
  String get _userId {
    if (_auth.currentUser != null) {
      return _auth.currentUser!.uid;
    } else {
      // Generate a device-specific ID for anonymous users
      // In a real app, you might want to store this ID in secure storage
      return 'anonymous_user';
    }
  }

  // Collection references
  CollectionReference get _conversationsCollection =>
      _firestore.collection('users').doc(_userId).collection('conversations');

  // Create a new conversation and return its ID
  Future<String> createConversation(String title) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      final docRef = await _conversationsCollection.add({
        'title': title,
        'created_at': now,
        'updated_at': now,
      });

      return docRef.id;
    } catch (e) {
      print('Error creating conversation: $e');
      rethrow;
    }
  }

  // Save messages to a conversation
  Future<void> saveMessages(
    String conversationId,
    List<Message> messages,
  ) async {
    try {
      final batch = _firestore.batch();
      final conversationRef = _conversationsCollection.doc(conversationId);
      final messagesCollection = conversationRef.collection('messages');

      // Update conversation timestamp
      batch.update(conversationRef, {
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Delete existing messages (this is a simplified approach; in production you might want
      // to implement more efficient updates that only add new messages)
      final existingMessages = await messagesCollection.get();
      for (var doc in existingMessages.docs) {
        batch.delete(doc.reference);
      }

      // Add all messages
      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];
        batch.set(messagesCollection.doc(i.toString()), {
          'index': i,
          'is_user': message.isUser,
          'text': message.text,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'status': message.status.toString().split('.').last,
          'image_url': message.imageUrl,
          'file_path': message.filePath,
          'file_name': message.fileName,
          'audio_path': message.audioPath,
          'follow_up_tags': message.followUpTags,
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error saving messages: $e');
      rethrow;
    }
  }

  // Get all conversations for the current user
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final snapshot =
          await _conversationsCollection
              .orderBy('updated_at', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Conversation',
          'created_at': data['created_at'] ?? 0,
          'updated_at': data['updated_at'] ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  // Get all messages for a conversation
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final snapshot =
          await _conversationsCollection
              .doc(conversationId)
              .collection('messages')
              .orderBy('index')
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Message(
          isUser: data['is_user'] ?? false,
          text: data['text'] ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            data['timestamp'] ?? 0,
          ),
          status: _parseMessageStatus(data['status'] ?? 'delivered'),
          imageUrl: data['image_url'],
          filePath: data['file_path'],
          fileName: data['file_name'],
          audioPath: data['audio_path'],
          followUpTags: (data['follow_up_tags'] ?? []).cast<String>(),
        );
      }).toList();
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  // Delete a conversation and all its messages
  Future<void> deleteConversation(String conversationId) async {
    try {
      final conversationRef = _conversationsCollection.doc(conversationId);

      // Delete all messages in the conversation
      final messagesSnapshot =
          await conversationRef.collection('messages').get();
      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the conversation document
      batch.delete(conversationRef);

      await batch.commit();
    } catch (e) {
      print('Error deleting conversation: $e');
      rethrow;
    }
  }

  // Update conversation title
  Future<void> updateConversationTitle(
    String conversationId,
    String title,
  ) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'title': title,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error updating conversation title: $e');
      rethrow;
    }
  }

  // Helper method to parse MessageStatus from string
  MessageStatus _parseMessageStatus(String status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'error':
        return MessageStatus.error;
      case 'delivered':
      default:
        return MessageStatus.delivered;
    }
  }
}
