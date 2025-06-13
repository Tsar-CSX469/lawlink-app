import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:lawlink/services/chatbot_service.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final ChatUser _currentUser = ChatUser(
    id: '1',
    firstName: 'User',
    profileImage: null,
  );

  final ChatUser _aiUser = ChatUser(
    id: '2',
    firstName: 'LawLink AI',
    profileImage: null,
  );

  final List<ChatMessage> _messages = [];
  final ChatbotService _chatbotService = ChatbotService();

  // Voice Recording
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isListening = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  String _recordedAudioPath = '';

  // File Upload
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _requestPermissions();
    await _initializeSpeech();
    await _initializeTts();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await Permission.camera.request();
  }

  Future<void> _initializeSpeech() async {
    await _speechToText.initialize();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage(
      user: _aiUser,
      createdAt: DateTime.now(),
      text:
          "Hello! I'm LawLink AI, your legal assistant. I can help you with Sri Lankan law queries, analyze documents, and answer questions about legal acts. How can I assist you today?",
    );
    setState(() {
      _messages.insert(0, welcomeMessage);
    });
  }

  Future<void> _sendMessage(ChatMessage message) async {
    setState(() {
      _messages.insert(0, message);
    });

    // Send message to AI service
    try {
      final response = await _chatbotService.sendMessage(message.text);
      final aiMessage = ChatMessage(
        user: _aiUser,
        createdAt: DateTime.now(),
        text: response,
      );

      setState(() {
        _messages.insert(0, aiMessage);
      });

      // Optional: Read the response aloud
      if (response.isNotEmpty) {
        await _speakText(response);
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        user: _aiUser,
        createdAt: DateTime.now(),
        text:
            "I apologize, but I'm having trouble processing your request. Please try again later. Error: $e",
      );

      setState(() {
        _messages.insert(0, errorMessage);
      });
    }
  }

  Future<void> _speakText(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _startListening() async {
    if (await _speechToText.hasPermission) {
      setState(() {
        _isListening = true;
      });

      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            final message = ChatMessage(
              user: _currentUser,
              createdAt: DateTime.now(),
              text: result.recognizedWords,
            );
            _sendMessage(message);
            _stopListening();
          }
        },
      );
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final path =
          '${Directory.systemTemp.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _recordedAudioPath = path;
      });
    }
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (_recordedAudioPath.isNotEmpty) {
      _showAudioMessageDialog();
    }
  }

  void _showAudioMessageDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Audio Message'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _playRecording,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton(
                      onPressed: _deleteRecording,
                      icon: const Icon(Icons.delete),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _sendAudioMessage();
                },
                child: const Text('Send'),
              ),
            ],
          ),
    );
  }

  Future<void> _playRecording() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordedAudioPath));
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _deleteRecording() {
    setState(() {
      _recordedAudioPath = '';
      _isPlaying = false;
    });
    Navigator.pop(context);
  }

  Future<void> _sendAudioMessage() async {
    final message = ChatMessage(
      user: _currentUser,
      createdAt: DateTime.now(),
      text: "🎵 Audio message",
      medias: [
        ChatMedia(
          url: _recordedAudioPath,
          fileName: "voice_message.m4a",
          type: MediaType.file,
        ),
      ],
    );

    setState(() {
      _messages.insert(0, message);
    });

    // Process audio with speech-to-text
    // Note: In a real implementation, you would send the audio to a speech-to-text service
    final response = await _chatbotService.sendMessage(
      "User sent an audio message",
    );
    final aiMessage = ChatMessage(
      user: _aiUser,
      createdAt: DateTime.now(),
      text: response,
    );

    setState(() {
      _messages.insert(0, aiMessage);
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      _sendImageMessage(pickedFile.path);
    }
  }

  Future<void> _pickGalleryImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      _sendImageMessage(pickedFile.path);
    }
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      _sendDocumentMessage(file);
    }
  }

  void _sendImageMessage(String imagePath) {
    final message = ChatMessage(
      user: _currentUser,
      createdAt: DateTime.now(),
      text: "📷 Image shared",
      medias: [
        ChatMedia(
          url: imagePath,
          fileName: imagePath.split('/').last,
          type: MediaType.image,
        ),
      ],
    );

    setState(() {
      _messages.insert(0, message);
    });

    // Process image with AI
    _processImageWithAI(imagePath);
  }

  void _sendDocumentMessage(PlatformFile file) {
    final message = ChatMessage(
      user: _currentUser,
      createdAt: DateTime.now(),
      text: "📄 Document: ${file.name}",
      medias: [
        ChatMedia(url: file.path!, fileName: file.name, type: MediaType.file),
      ],
    );

    setState(() {
      _messages.insert(0, message);
    });

    // Process document with AI
    _processDocumentWithAI(file);
  }

  Future<void> _processImageWithAI(String imagePath) async {
    try {
      final response = await _chatbotService.analyzeImage(imagePath);
      final aiMessage = ChatMessage(
        user: _aiUser,
        createdAt: DateTime.now(),
        text: response,
      );

      setState(() {
        _messages.insert(0, aiMessage);
      });
    } catch (e) {
      _showErrorMessage("Error analyzing image: $e");
    }
  }

  Future<void> _processDocumentWithAI(PlatformFile file) async {
    try {
      final response = await _chatbotService.analyzeDocument(file);
      final aiMessage = ChatMessage(
        user: _aiUser,
        createdAt: DateTime.now(),
        text: response,
      );

      setState(() {
        _messages.insert(0, aiMessage);
      });
    } catch (e) {
      _showErrorMessage("Error analyzing document: $e");
    }
  }

  void _showErrorMessage(String error) {
    final errorMessage = ChatMessage(
      user: _aiUser,
      createdAt: DateTime.now(),
      text: error,
    );

    setState(() {
      _messages.insert(0, errorMessage);
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose Attachment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: _pickImage,
                    ),
                    _buildAttachmentOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: _pickGalleryImage,
                    ),
                    _buildAttachmentOption(
                      icon: Icons.description,
                      label: 'Document',
                      onTap: _pickDocument,
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.shade100,
            child: Icon(icon, color: Colors.blue.shade600, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LawLink AI Assistant'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              _addWelcomeMessage();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator
          if (_isListening || _isRecording)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListening
                        ? 'Listening...'
                        : _isRecording
                        ? 'Recording...'
                        : '',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),

          // Chat interface
          Expanded(
            child: DashChat(
              currentUser: _currentUser,
              onSend: _sendMessage,
              messages: _messages,
              messageOptions: MessageOptions(
                showCurrentUserAvatar: true,
                showOtherUsersAvatar: true,
                showTime: true,
                avatarBuilder: (user, onPressAvatar, onLongPressAvatar) {
                  return CircleAvatar(
                    backgroundColor:
                        user.id == '1' ? Colors.blue : Colors.green,
                    child: Text(
                      user.firstName?.substring(0, 1) ?? '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
              inputOptions: InputOptions(
                trailing: [
                  // Voice message button
                  IconButton(
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording ? Colors.red : Colors.blue,
                    ),
                  ),
                  // Speech-to-text button
                  IconButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    icon: Icon(
                      _isListening ? Icons.mic_off : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.blue,
                    ),
                  ),
                  // Attachment button
                  IconButton(
                    onPressed: _showAttachmentOptions,
                    icon: const Icon(Icons.attach_file, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
