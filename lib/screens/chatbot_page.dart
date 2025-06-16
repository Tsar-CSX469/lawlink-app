import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import 'package:lawlink/services/chatbot_service.dart';
import 'package:lawlink/services/elevenlabs_service.dart';

class Message {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final String? imageUrl;
  final String? filePath;
  final String? fileName;
  final String? audioPath;

  Message({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.delivered,
    this.imageUrl,
    this.filePath,
    this.fileName,
    this.audioPath,
  });

  Content toGeminiContent() {
    final role = isUser ? 'user' : 'assistant';
    final parts = [TextPart(text)];
    return Content(role, parts);
  }
}

enum MessageStatus { sending, delivered, error }

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final List<Message> _messages = [];
  // final ChatbotService _chatbotService = ChatbotService();
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  final TextEditingController _textController = TextEditingController();
  // Voice Recording
  final SpeechToText _speechToText = SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Language selection
  String _selectedLanguage = 'English'; // Default language

  bool _isListening = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isProcessing = false;
  String _recordedAudioPath = '';
  ScrollController _scrollController = ScrollController();

  late ChatbotService _chatbotService;

  @override
  void initState() {
    super.initState();
    _chatbotService = ChatbotService(); // Initialize here
    _initializeSpeech();
    _requestPermissions();
    _addWelcomeMessage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  // File Upload
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _requestPermissions();
    await _initializeSpeech();
  }

  Future<void> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus.isDenied) {
      // Show a dialog explaining why microphone permission is needed
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Microphone Permission Required'),
              content: const Text(
                'LawLink AI needs microphone access for speech recognition and voice messages. Please grant permission in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }

    // Request other permissions
    await Permission.storage.request();
    await Permission.camera.request();
  }

  Future<void> _initializeSpeech() async {
    try {
      final hasSpeech = await _speechToText.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech recognition status: $status'),
      );

      if (!hasSpeech) {
        print('Speech recognition initialization failed');
        // Show a brief error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available on this device'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error initializing speech recognition: $e');
    }
  }

  void _addWelcomeMessage() {
    String welcomeText =
        _selectedLanguage == 'English'
            ? "Hello! I'm LawLink AI, your legal assistant. I can help you with Sri Lankan law queries, analyze documents, and answer questions about legal acts. How can I assist you today?"
            : "ආයුබෝවන්! මම LawLink AI, ඔබගේ නීති සහායකයා. මට ශ්‍රී ලංකා නීති ප්‍රශ්න, ලේඛන විශ්ලේෂණය කිරීමට සහ නීති පනත් පිළිබඳ ප්‍රශ්නවලට පිළිතුරු දීමට උපකාර කළ හැකිය. අද දින මට ඔබට කෙසේ උපකාර කළ හැකිද?";

    final welcomeMessage = Message(
      isUser: false,
      text: welcomeText,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(welcomeMessage);
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = Message(
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isProcessing = true;
    });

    _scrollToBottom();
    _textController.clear();
    try {
      List<Message> historyToSend = List.from(_messages);
      const int maxTurns = 10;
      if (historyToSend.length > maxTurns) {
        historyToSend = historyToSend.sublist(historyToSend.length - maxTurns);
      }
      final response = await _chatbotService.sendMessage(text, historyToSend);

      final aiMessage = Message(
        isUser: false,
        text: response,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isProcessing = false;
      });
      _scrollToBottom();
    } catch (e) {
      final errorMessage = Message(
        isUser: false,
        text:
            "I apologize, but I'm having trouble processing your request. Please try again later. Error: $e",
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );

      setState(() {
        _messages.add(errorMessage);
        _isProcessing = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _speakText(String text) async {
    // Stop any currently playing audio
    if (_audioPlayer.state == PlayerState.playing) {
      await _audioPlayer.stop();
    }

    // Show loading indicator
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating premium audio...'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } catch (e) {
      print('Snackbar error: $e');
    }

    try {
      // Limit text length if too long (ElevenLabs has character limits)
      String processedText = text;
      if (text.length > 1000) {
        processedText = text.substring(0, 1000) + "...";
      }

      final audioPath = await _elevenLabsService.textToSpeech(processedText);

      if (audioPath != null) {
        await _audioPlayer.play(DeviceFileSource(audioPath));
      } else {
        // Show error message if audio generation failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate audio. Please try again.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      print('ElevenLabs error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audio generation error: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  Future<void> _startListening() async {
    final hasPermission = await _speechToText.hasPermission;

    if (!hasPermission) {
      // Request permission again if not granted
      await _requestPermissions();
      return;
    }

    setState(() {
      _isListening = true;
    });
    // Show feedback to the user
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listening... Speak now'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } catch (e) {
      print('Snackbar error: $e');
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            // Show partial results in the text field
            setState(() {
              _textController.text = result.recognizedWords;
            });
          }

          if (result.finalResult) {
            if (result.recognizedWords.isNotEmpty) {
              _sendMessage(result.recognizedWords);
            }
            _stopListening();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      print('Error during speech recognition: $e');
      _stopListening();
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _startRecording() async {
    try {
      // Check if we're running on web - recording works differently there
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Audio recording not fully supported in web preview mode.',
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.fixed,
          ),
        );
        return;
      }

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        // Request permission if not granted
        await Permission.microphone.request();
        return;
      }

      // Create a unique file path for the recording
      String path;
      try {
        path =
            '${Directory.systemTemp.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } catch (e) {
        // Fallback for web or platforms without systemTemp
        path = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      // Start recording with better audio quality
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordedAudioPath = path;
      });
      // Provide feedback to the user
      try {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording audio message...'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      } catch (e) {
        print('Snackbar error: $e');
      }
    } catch (e) {
      print('Error starting recording: $e');
      try {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start recording: $e'),
            backgroundColor: Colors.red[900],
            behavior: SnackBarBehavior.fixed,
          ),
        );
      } catch (e) {
        print('Snackbar error: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (_recordedAudioPath.isNotEmpty) {
        _showAudioMessageDialog();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _showAudioMessageDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.mic, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text('Audio Message'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your audio message is ready. Would you like to listen to it before sending?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        onPressed: _playRecording,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 36,
                        ),
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        onPressed: _deleteRecording,
                        icon: const Icon(Icons.delete_rounded, size: 36),
                        color: Colors.red[400],
                      ),
                    ),
                  ],
                ),
              ],
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _sendAudioMessage();
                },
                child: const Text('Send Message'),
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
    // Add message with audio attachment
    final userMessage = Message(
      isUser: true,
      text: "🎵 Audio message",
      timestamp: DateTime.now(),
      audioPath: _recordedAudioPath,
    );

    setState(() {
      _messages.add(userMessage);
      _isProcessing = true;
    });

    _scrollToBottom();

    // Process audio with speech-to-text
    // Note: In a real implementation, you would send the audio to a speech-to-text service
    final response = await _chatbotService.sendMessage(
      "User sent an audio message",
      List.from(_messages),
    );
    final aiMessage = Message(
      isUser: false,
      text: response,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(aiMessage);
      _isProcessing = false;
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
    final message = Message(
      isUser: true,
      text: "📷 Image shared",
      timestamp: DateTime.now(),
      imageUrl: imagePath,
      fileName: imagePath.split('/').last,
    );

    setState(() {
      _messages.add(message);
      _isProcessing = true;
    });

    _scrollToBottom();

    // Process image with AI
    _processImageWithAI(imagePath);
  }

  void _sendDocumentMessage(PlatformFile file) {
    final message = Message(
      isUser: true,
      text: "📄 Document: ${file.name}",
      timestamp: DateTime.now(),
      filePath: file.path,
      fileName: file.name,
    );

    setState(() {
      _messages.add(message);
      _isProcessing = true;
    });

    _scrollToBottom();

    // Process document with AI
    _processDocumentWithAI(file);
  }

  Future<void> _processImageWithAI(String imagePath) async {
    try {
      final response = await _chatbotService.analyzeImage(imagePath);
      final aiMessage = Message(
        isUser: false,
        text: response,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isProcessing = false;
      });

      _scrollToBottom();
    } catch (e) {
      _showErrorMessage("Error analyzing image: $e");
    }
  }

  Future<void> _processDocumentWithAI(PlatformFile file) async {
    try {
      final response = await _chatbotService.analyzeDocument(file);
      final aiMessage = Message(
        isUser: false,
        text: response,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isProcessing = false;
      });

      _scrollToBottom();
    } catch (e) {
      _showErrorMessage("Error analyzing document: $e");
    }
  }

  void _showErrorMessage(String error) {
    final errorMessage = Message(
      isUser: false,
      text: error,
      timestamp: DateTime.now(),
      status: MessageStatus.error,
    );

    setState(() {
      _messages.add(errorMessage);
      _isProcessing = false;
    });

    _scrollToBottom();
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

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade700 : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null)
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(message.imageUrl!), fit: BoxFit.cover),
                ),
              ),
            if (message.filePath != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        message.fileName ?? 'File',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (message.audioPath != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: isUser ? Colors.white : Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Audio Message',
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            isUser
                ? Text(
                  message.text,
                  style: const TextStyle(color: Colors.white),
                )
                : MarkdownBody(
                  data: message.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: isUser ? Colors.white : Colors.black87),
                    h1: TextStyle(color: isUser ? Colors.white : Colors.black),
                    h2: TextStyle(color: isUser ? Colors.white : Colors.black),
                    h3: TextStyle(color: isUser ? Colors.white : Colors.black),
                    code: TextStyle(
                      backgroundColor:
                          isUser ? Colors.blue[900] : Colors.grey[200],
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                    blockquote: TextStyle(
                      color: isUser ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : Colors.grey[500],
                  ),
                ),
                if (!isUser) // Only show for AI messages
                  GestureDetector(
                    onTap: () => _speakText(message.text),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Tooltip(
                          message: "Play with premium voice",
                          child: Icon(
                            Icons.spatial_audio_rounded,
                            size: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    // Calculate bottom padding to account for the notch/home indicator if present
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 16,
        bottom:
            16 +
            bottomPadding, // Add extra padding at bottom to account for system notch
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Speech-to-text button with tooltip
          Tooltip(
            message: _isListening ? "Stop listening" : "Speak a message",
            child: Container(
              decoration: BoxDecoration(
                color:
                    _isListening
                        ? Colors.red.withOpacity(0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_outlined,
                  size: 24,
                ),
                onPressed: _isListening ? _stopListening : _startListening,
                color: _isListening ? Colors.red : Colors.blue[700],
              ),
            ),
          ),
          // Audio recording button with tooltip
          Tooltip(
            message: _isRecording ? "Stop recording" : "Record audio message",
            child: Container(
              decoration: BoxDecoration(
                color:
                    _isRecording
                        ? Colors.red.withOpacity(0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                  size: 22,
                ),
                onPressed: _isRecording ? _stopRecording : _startRecording,
                color: _isRecording ? Colors.red : Colors.red[400],
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Message LawLink AI...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _sendMessage(text);
                }
              },
            ),
          ),
          // Attachment button with tooltip
          Tooltip(
            message: "Add attachment",
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showAttachmentOptions,
              color: Colors.blue[700],
            ),
          ),
          // Send button with animated container
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  _sendMessage(_textController.text);
                }
              },
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _setLanguageSystemPrompt(String language) {
    // Add a system message to set the language (not visible to user)

    // Send system message to chatbot service without displaying in UI
    _chatbotService.sendSystemPrompt(language);

    // Add a user-visible message about language change
    final Message languageChangeMessage = Message(
      isUser: false,
      text:
          language == 'English'
              ? "Language changed to English. I'll respond in English from now on."
              : "භාෂාව සිංහල බවට වෙනස් කරන ලදී. මින් ඉදිරියට මම සිංහලෙන් පිළිතුරු දෙන්නෙමි.",
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(languageChangeMessage);
    });

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            // Only add a subtle bottom border
            border: Border(
              bottom: BorderSide(
                color: Colors.blue.withOpacity(0.2),
                width: 0.5,
              ),
            ),
          ),
          child: AppBar(
            title: ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
              child: const Text(
                'LawLink AI',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            centerTitle: false,
            iconTheme: IconThemeData(color: Colors.blue.shade700),
            actions: [
              // Language Selector
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  icon: Icon(
                    Icons.language,
                    color: Colors.blue.shade700,
                    size: 19,
                  ),
                  underline: Container(),
                  isDense: true, // Makes the button compact
                  itemHeight: 48, // Smaller item height
                  style: TextStyle(
                    fontSize: 13, // Smaller font size
                    color: Colors.blue.shade800,
                  ),
                  dropdownColor: Colors.white, // White dropdown menu background
                  borderRadius: BorderRadius.circular(
                    8,
                  ), // Rounded corners for dropdown
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue != _selectedLanguage) {
                      setState(() {
                        _selectedLanguage = newValue;
                      });
                      _setLanguageSystemPrompt(newValue);
                    }
                  },
                  items:
                      <String>['English', 'සිංහල'] // English, Sinhala
                      .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(
                width: 4,
              ), // Smaller gap between language selector and refresh button
              IconButton(
                onPressed: () {
                  setState(() {
                    _messages.clear();
                  });
                  _addWelcomeMessage();
                },
                icon: Icon(Icons.refresh, color: Colors.blue.shade700),
                tooltip: 'Clear chat',
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
            // Main content area with SafeArea
            Expanded(
              child: SafeArea(
                bottom: false, // Don't apply bottom safe area
                child: Column(
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
                      ), // Modern Chat Interface
                    Expanded(
                      child: Container(
                        color: Colors.transparent,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _messages.length + (_isProcessing ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator for AI response
                            if (_isProcessing && index == _messages.length) {
                              return _buildTypingIndicator();
                            }

                            final message = _messages[index];
                            return _buildMessageItem(message);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Input area outside SafeArea to extend to bottom edge
            _buildInputArea(),
          ],
        ),
      ),
    );
  }
}
