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

      return docRef.id;    } catch (e) {
      _logError('createConversation', e);
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
      
      // Check if the conversation document exists
      final docSnapshot = await conversationRef.get();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (docSnapshot.exists) {
        // Update conversation timestamp
        batch.update(conversationRef, {
          'updated_at': now,
        });
      } else {
        // Create the conversation document if it doesn't exist
        batch.set(conversationRef, {
          'title': 'New Conversation',
          'created_at': now,
          'updated_at': now,
        });
      }

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

      await batch.commit();    } catch (e) {
      _logError('saveMessages', e, 'conversationId: $conversationId');
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
      }).toList();    } catch (e) {
      _logError('getConversations', e);
      return [];
    }
  }
  // Get all messages for a conversation
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      // First check if the conversation exists
      final conversationRef = _conversationsCollection.doc(conversationId);
      final conversationDoc = await conversationRef.get();
      
      if (!conversationDoc.exists) {
        print('Warning: Conversation $conversationId does not exist');
        return []; // Return empty list if conversation doesn't exist
      }
      
      final snapshot =
          await conversationRef
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
      }).toList();    } catch (e) {
      _logError('getMessages', e, 'conversationId: $conversationId');
      return [];
    }
  }
  // Delete a conversation and all its messages
  Future<void> deleteConversation(String conversationId) async {
    try {
      final conversationRef = _conversationsCollection.doc(conversationId);
      
      // Check if the conversation exists
      final conversationDoc = await conversationRef.get();
      if (!conversationDoc.exists) {
        print('Warning: Conversation $conversationId does not exist, nothing to delete');
        return; // Nothing to delete
      }

      // Delete all messages in the conversation
      final messagesSnapshot =
          await conversationRef.collection('messages').get();
      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the conversation document
      batch.delete(conversationRef);

      await batch.commit();    } catch (e) {
      _logError('deleteConversation', e, 'conversationId: $conversationId');
      rethrow;
    }
  }
  // Update conversation title
  Future<void> updateConversationTitle(
    String conversationId,
    String title,
  ) async {
    try {
      final conversationRef = _conversationsCollection.doc(conversationId);
      final docSnapshot = await conversationRef.get();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (docSnapshot.exists) {
        await conversationRef.update({
          'title': title,
          'updated_at': now,
        });
      } else {
        // Create the conversation document if it doesn't exist
        await conversationRef.set({
          'title': title,
          'created_at': now,
          'updated_at': now,
        });
      }    } catch (e) {
      _logError('updateConversationTitle', e, 'conversationId: $conversationId');
      rethrow;
    }
  }

  // Check if a conversation exists
  Future<bool> conversationExists(String conversationId) async {
    try {
      final docSnapshot = await _conversationsCollection.doc(conversationId).get();
      return docSnapshot.exists;    } catch (e) {
      _logError('conversationExists', e, 'conversationId: $conversationId');
      return false;
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

  // Helper method to log errors (could be enhanced with Firebase Analytics in the future)
  void _logError(String operation, dynamic error, [String? details]) {
    final errorMessage = 'Firebase Chat Error - $operation: $error ${details != null ? '- $details' : ''}';
    print(errorMessage);
    // TODO: In the future, consider adding Firebase Crashlytics or Analytics logging here
    // FirebaseCrashlytics.instance.recordError(error, StackTrace.current, reason: details);
  }
}
