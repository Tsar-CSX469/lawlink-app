import 'dart:convert';
// import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:lawlink/screens/chatbot_page.dart'; // For Message class

class ChatStorageService {
  static final ChatStorageService _instance = ChatStorageService._internal();
  static Database? _database;

  factory ChatStorageService() {
    return _instance;
  }

  ChatStorageService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'lawlink_chats.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create conversations table
        await db.execute('''CREATE TABLE conversations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            created_at INTEGER,
            updated_at INTEGER
          )''');

        // Create messages table
        await db.execute('''CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER,
            is_user INTEGER,
            text TEXT,
            timestamp INTEGER,
            status TEXT,
            image_url TEXT,
            file_path TEXT,
            file_name TEXT,
            audio_path TEXT,
            follow_up_tags TEXT,
            FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
          )''');
      },
    );
  }

  // Create a new conversation and return its ID
  Future<int> createConversation(String title) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.insert('conversations', {
      'title': title,
      'created_at': now,
      'updated_at': now,
    });
  }

  // Save a message to a conversation
  Future<void> saveMessage(int conversationId, Message message) async {
    final db = await database;

    await db.insert('messages', {
      'conversation_id': conversationId,
      'is_user': message.isUser ? 1 : 0,
      'text': message.text,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'status': message.status.toString().split('.').last,
      'image_url': message.imageUrl,
      'file_path': message.filePath,
      'file_name': message.fileName,
      'audio_path': message.audioPath,
      'follow_up_tags': jsonEncode(message.followUpTags),
    });
  }

  // Save multiple messages at once (for bulk operations)
  Future<void> saveMessages(int conversationId, List<Message> messages) async {
    final db = await database;
    final batch = db.batch();

    for (var message in messages) {
      batch.insert('messages', {
        'conversation_id': conversationId,
        'is_user': message.isUser ? 1 : 0,
        'text': message.text,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
        'status': message.status.toString().split('.').last,
        'image_url': message.imageUrl,
        'file_path': message.filePath,
        'file_name': message.fileName,
        'audio_path': message.audioPath,
        'follow_up_tags': jsonEncode(message.followUpTags),
      });
    }

    await batch.commit(noResult: true);

    // Update conversation updated_at timestamp
    await db.update(
      'conversations',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  // Get all conversations sorted by most recent
  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;

    return await db.query('conversations', orderBy: 'updated_at DESC');
  }

  // Get all messages for a conversation
  Future<List<Message>> getMessages(int conversationId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return Message(
        isUser: maps[i]['is_user'] == 1,
        text: maps[i]['text'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp']),
        status: _parseMessageStatus(maps[i]['status']),
        imageUrl: maps[i]['image_url'],
        filePath: maps[i]['file_path'],
        fileName: maps[i]['file_name'],
        audioPath: maps[i]['audio_path'],
        followUpTags:
            (jsonDecode(maps[i]['follow_up_tags'] ?? '[]') as List)
                .cast<String>(),
      );
    });
  }

  // Delete a conversation and all its messages
  Future<void> deleteConversation(int conversationId) async {
    final db = await database;

    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );

    // Messages will be deleted automatically due to CASCADE
  }

  // Update conversation title
  Future<void> updateConversationTitle(int conversationId, String title) async {
    final db = await database;

    await db.update(
      'conversations',
      {'title': title, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
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
