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
import 'dart:math';
import 'package:lawlink/services/chatbot_service.dart';
import 'package:lawlink/services/elevenlabs_service.dart';
import 'package:flutter/services.dart';
import 'package:lawlink/services/firebase_chat_storage_service.dart';
import 'package:lawlink/services/chatbot_initialization_service.dart';
import 'package:lawlink/screens/conversation_list_page.dart';

class Message {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final String? imageUrl;
  final String? filePath;
  final String? fileName;
  final String? audioPath;
  final List<String> followUpTags;

  Message({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.delivered,
    this.imageUrl,
    this.filePath,
    this.fileName,
    this.audioPath,
    this.followUpTags = const [],
  });
  Content toGeminiContent() {
    final role = isUser ? 'user' : 'model';
    final parts = [TextPart(text)];
    return Content(role, parts);
  }

  // Extract follow-up tags from message text
  static List<String> extractFollowUpTags(String text) {
    List<String> tags = [];
    // Look for the pattern "**Want to know more?**" followed by bullet points
    final regex = RegExp(r'\*\*Want to know more\?\*\*\n([\s\S]+)');
    final match = regex.firstMatch(text);

    if (match != null && match.groupCount >= 1) {
      final tagSection = match.group(1);
      if (tagSection != null) {
        // Extract each bullet point
        final tagLines =
            tagSection
                .split('\n')
                .where((line) => line.trim().startsWith('-'))
                .toList();
        // Process each bullet point to extract the actual tag text
        tags =
            tagLines.map((line) {
              String cleanLine = line.trim();
              if (cleanLine.startsWith('- ')) {
                return cleanLine.substring(2).trim();
              } else if (cleanLine.startsWith('-')) {
                return cleanLine.substring(1).trim();
              }
              return cleanLine;
            }).toList();
      }
    }

    return tags;
  } // Get message text without the follow-up tags section

  String get cleanText {
    // If there are no follow-up tags, return the entire text
    if (followUpTags.isEmpty) {
      print(
        'NO FOLLOW-UP TAGS, RETURNING FULL TEXT: ${text.substring(0, min(50, text.length))}...',
      );
      return text;
    }

    // Look for the pattern that marks the beginning of follow-up tags section
    final tagSectionStart = text.indexOf('**Want to know more?**');
    if (tagSectionStart != -1) {
      // Return only the part before the tag section
      String mainContent = text.substring(0, tagSectionStart).trim();
      print('MAIN CONTENT LENGTH: ${mainContent.length}');
      print(
        'MAIN CONTENT FIRST 50 CHARS: ${mainContent.substring(0, min(50, mainContent.length))}...',
      );

      // Ensure we have content in the main part
      if (mainContent.isEmpty) {
        print('MAIN CONTENT IS EMPTY, FALLING BACK TO FIRST PARAGRAPH');
        // If somehow the main content is empty, fall back to the first part of the text
        List<String> paragraphs = text.split('\n\n');
        if (paragraphs.isNotEmpty) {
          String firstParagraph = paragraphs[0];
          print('FIRST PARAGRAPH: $firstParagraph');
          return firstParagraph;
        }
      }
      return mainContent;
    }

    // If pattern isn't found but we have follow-up tags,
    // we might need to extract content differently
    print('PATTERN NOT FOUND BUT HAS FOLLOW-UP TAGS, RETURNING FULL TEXT');
    return text;
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

  // Firebase Chat Storage
  final FirebaseChatStorageService _chatStorageService =
      FirebaseChatStorageService();
  String? _currentConversationId;
  bool _isNewConversation = true;
  String _conversationTitle = "New Conversation";
  bool _isLoading = false; // Loading state for conversations

  // Language selection
  String _selectedLanguage = 'English'; // Default language

  bool _isListening = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isProcessing = false;
  String _recordedAudioPath = '';
  final ScrollController _scrollController = ScrollController();

  late ChatbotService? _chatbotService;
  @override
  void initState() {
    super.initState();

    // Initialize chatbot service safely
    try {
      _chatbotService = ChatbotService();
      print('✅ ChatbotService created in initState');
    } catch (e) {
      print('❌ Failed to create ChatbotService in initState: $e');
      _chatbotService = null;
    }

    // Initialize without blocking the UI
    _isLoading = false;

    // Simple initialization without blocking dialogs
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _quickInitialization();
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

  /// Quick, non-blocking initialization
  Future<void> _quickInitialization() async {
    // Initialize speech in background first (no blocking dialogs)
    try {
      await _initializeSpeech();
    } catch (e) {
      print('Speech initialization failed: $e');
    }

    // Check if permissions were already granted via the initialization service
    if (ChatbotInitializationService.isReady) {
      // All good, nothing more to do
    } else {
      // If not ready, the floating button handled permissions,
      // so we can just show a subtle indicator that some features might be limited
      print('Chatbot not fully initialized, some features may be limited');
    }

    // Add welcome message after a short delay to ensure UI is ready
    await Future.delayed(const Duration(milliseconds: 100));
    if (_messages.isEmpty) {
      setState(() {
        _addWelcomeMessage();
      });
      // Force scroll to bottom after the UI updates
      await Future.delayed(const Duration(milliseconds: 200));
      _ensureWelcomeMessageVisible();
    }
  }

  Future<void> _requestPermissions() async {
    // Use the initialization service instead of showing blocking dialogs
    if (!ChatbotInitializationService.isReady) {
      // The initialization service will handle permissions gracefully
      await ChatbotInitializationService.initializeAsync(context: context);
    }
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
    // Clear any existing messages first
    _messages.clear();

    String welcomeText =
        _selectedLanguage == 'English'
            ? "Hello! I'm LawLink AI, your legal assistant. I can help you with Sri Lankan law queries, analyze documents, and answer questions about legal acts. How can I assist you today?"
            : "ආයුබෝවන්! මම LawLink AI, ඔබගේ නීති සහායකයා. මට ශ්‍රී ලංකා නීති ප්‍රශ්න, ලේඛන විශ්ලේෂණය කිරීමට සහ නීති පනත් පිළිබඳ ප්‍රශ්නවලට පිළිතුරු දීමට උපකාර කළ හැකිය. අද දින මට ඔබට කෙසේ උපකාර කළ හැකිද?";

    // Add some suggested starter questions as follow-up tags
    List<String> starterTags = [
      "What are consumer rights in Sri Lanka?",
      "How do I file a legal complaint?",
      "Tell me about the court system",
    ];

    final welcomeMessage = Message(
      isUser: false,
      text: welcomeText,
      timestamp: DateTime.now(),
      followUpTags: starterTags,
    );

    _messages.add(welcomeMessage);
  }

  void _ensureWelcomeMessageVisible() {
    // Make sure to scroll down to show the welcome message with multiple attempts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _messages.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });

    // Additional delayed scroll attempt to ensure it works
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && _messages.isNotEmpty) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Check if chatbot service is available
    if (_chatbotService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chatbot service is not available. Please try again later.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if the text is a follow-up tag from a previous message
    bool isFollowUpTag = false;
    String originalQuery = text;

    // Look through recent AI messages to see if this matches a follow-up tag
    for (
      int i = _messages.length - 1;
      i >= 0 && i >= _messages.length - 5;
      i--
    ) {
      final message = _messages[i];
      if (!message.isUser && message.followUpTags.isNotEmpty) {
        for (final tag in message.followUpTags) {
          if (text.trim() == tag.trim()) {
            isFollowUpTag = true;
            originalQuery = "Regarding your previous answer, $tag";
            break;
          }
        }
        if (isFollowUpTag) break;
      }
    }

    // Check if this is the first user message (apart from the welcome message)
    bool isFirstUserMessage = !_messages.any((msg) => msg.isUser);

    // If this is the first user message, create a new conversation
    // But only if we don't already have a conversation ID (might be loaded from history)
    if (_currentConversationId == null) {
      // We'll create the conversation after the message is added
      // This ensures the user message is included in the conversation
      // We'll handle this in the auto-save logic
    }

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
      const int maxTurns = 15;
      if (historyToSend.length > maxTurns) {
        historyToSend = historyToSend.sublist(historyToSend.length - maxTurns);
      }

      // Use the original query with context if this is a follow-up tag
      final query = isFollowUpTag ? originalQuery : text;

      final response = await _chatbotService!.sendMessage(
        query,
        historyToSend,
        context: context,
      );

      // Extract follow-up tags from the response
      final followUpTags = Message.extractFollowUpTags(response);
      final aiMessage = Message(
        isUser: false,
        text: response,
        timestamp: DateTime.now(),
        followUpTags: followUpTags,
      );
      setState(
        () {
          _messages.add(aiMessage);
          _isProcessing = false;
        },
      ); // If this was the first user message, create the conversation immediately
      // This ensures the conversation name appears right after the first message
      if (isFirstUserMessage) {
        // Use the first user message as title
        String title = text.length > 30 ? text.substring(0, 30) + "..." : text;

        // Create conversation immediately instead of with a delay
        // But only if we don't already have a conversation ID
        if (_currentConversationId == null) {
          // This will create the conversation with the title
          await _createNewConversation(conversationTitle: title);

          // Save messages to the newly created conversation directly
          // No need for autosave when we can do it directly
          if (_currentConversationId != null) {
            try {
              await _chatStorageService.saveMessages(
                _currentConversationId!,
                _messages,
              );
              print(
                "First message saved directly to conversation: $_currentConversationId",
              );
            } catch (e) {
              print("Error saving first message: $e");
            }
          }
        }
      }
      // For subsequent messages, save directly without using autosave
      else if (_messages.length >= 3 && _currentConversationId != null) {
        try {
          await _chatStorageService.saveMessages(
            _currentConversationId!,
            _messages,
          );
        } catch (e) {
          print("Error saving subsequent messages: $e");
        }
      }

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
        processedText = "${text.substring(0, 1000)}...";
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
                Icon(Icons.mic, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Audio Message',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                  style: TextStyle(color: Colors.blue.shade700),
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

    _scrollToBottom(); // Process audio with speech-to-text
    // Note: In a real implementation, you would send the audio to a speech-to-text service
    final response = await _chatbotService!.sendMessage(
      "User sent an audio message",
      List.from(_messages),
      context: context,
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

    // Process image with AI and ask for a question
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

  Future<String?> _askImageQuestion(BuildContext context) {
    final TextEditingController questionController = TextEditingController();
    final String dialogTitle =
        _selectedLanguage == 'English'
            ? 'Add a question about this image'
            : 'මෙම රූපය ගැන ප්රශ්නයක් එකතු කරන්න';

    final String hintText =
        _selectedLanguage == 'English'
            ? 'What would you like to know about this image?'
            : 'මෙම රූපය ගැන ඔබ දැනගන්න කැමති කුමක්ද?';

    final String okButtonText =
        _selectedLanguage == 'English' ? 'Submit' : 'ඉදිරිපත් කරන්න';
    final String skipButtonText =
        _selectedLanguage == 'English' ? 'No Question' : 'ප්රශ්නයක් නැත';
    final String cancelButtonText =
        _selectedLanguage == 'English' ? 'Cancel' : 'අවලංගු කරන්න';

    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(dialogTitle),
            content: TextField(
              controller: questionController,
              decoration: InputDecoration(hintText: hintText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: Text(skipButtonText),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(cancelButtonText),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(context, questionController.text),
                child: Text(okButtonText),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _processImageWithAI(String imagePath) async {
    try {
      // Ask the user for a question about the image
      final userQuestion = await _askImageQuestion(context);

      // If user pressed Cancel, abort the image analysis
      if (userQuestion == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // If user provided a question, add it as a user message before sending to AI
      if (userQuestion.isNotEmpty) {
        setState(() {
          _messages.add(
            Message(
              isUser: true,
              text: userQuestion,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }

      // Analyze the image with the user's question
      final response = await _chatbotService!.analyzeImage(
        imagePath,
        userQuestion: userQuestion.isNotEmpty ? userQuestion : null,
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

      _scrollToBottom();
    } catch (e) {
      _showErrorMessage("Error analyzing image: $e");
    }
  }

  Future<void> _processDocumentWithAI(PlatformFile file) async {
    try {
      final response = await _chatbotService!.analyzeDocument(file);
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
                Text(
                  'Choose Attachment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
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
      child: GestureDetector(
        onLongPress: () {
          // Show options in a bottom sheet when long-pressing a message
          showModalBottomSheet(
            context: context,
            builder:
                (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.copy),
                      title: const Text('Copy entire message'),
                      onTap: () {
                        // Copy the message text to clipboard
                        Clipboard.setData(ClipboardData(text: message.text));
                        Navigator.pop(context);

                        // Show a feedback message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message copied to clipboard'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text(
                        'Tip: Tap and hold text to select and copy parts of the message',
                      ),
                    ),
                  ],
                ),
          );
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                isUser ? Colors.blue.shade700 : Colors.white.withOpacity(0.9),
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
                    child: Image.file(
                      File(message.imageUrl!),
                      fit: BoxFit.cover,
                    ),
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
                      Icon(
                        Icons.mic,
                        color: isUser ? Colors.white : Colors.blue,
                      ),
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
                  ? SelectableText(
                    message.text,
                    style: const TextStyle(color: Colors.white),
                    toolbarOptions: const ToolbarOptions(
                      copy: true,
                      selectAll: true,
                      cut: false,
                      paste: false,
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI message content
                      SelectionArea(
                        child: MarkdownBody(
                          data:
                              message
                                  .cleanText, // Use cleanText to hide the follow-up section
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                            ),
                            h1: TextStyle(
                              color: isUser ? Colors.white : Colors.black,
                            ),
                            h2: TextStyle(
                              color: isUser ? Colors.white : Colors.black,
                            ),
                            h3: TextStyle(
                              color: isUser ? Colors.white : Colors.black,
                            ),
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
                      ),

                      // Follow-up tags as clickable chips
                      if (message.followUpTags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          "Want to know more?",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 6.0,
                          children:
                              message.followUpTags.map((tag) {
                                return InkWell(
                                  onTap: () {
                                    _textController.text = tag;
                                    _sendMessage(tag);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline,
                                          size: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          tag,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                    ],
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
                      onTap:
                          () => _speakText(
                            message.cleanText,
                          ), // Use cleanText for speech
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
          // Note: Audio recording button removed, giving more space to the text field
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
    _chatbotService?.sendSystemPrompt(language);

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

  // Firebase conversation management methods
  Future<void> _createNewConversation({String? conversationTitle}) async {
    try {
      // Only create the conversation if we have at least one user message or explicit title
      if (_messages.any((msg) => msg.isUser) || conversationTitle != null) {
        _currentConversationId = await _chatStorageService.createConversation(
          conversationTitle ?? "New Chat",
        );

        // Always update these two variables, they control when/if the title is displayed
        setState(() {
          _conversationTitle = conversationTitle ?? "New Chat";
          _isNewConversation =
              false; // Set to false immediately so title shows in app bar
        });

        // Only clear existing messages if explicitly starting a new conversation from menu button
        // NOT when creating from the first user message in a chat
        if (conversationTitle == null) {
          // No title provided means it's from menu button
          setState(() {
            _messages.clear();
            _addWelcomeMessage();
          });
          // Ensure the welcome message is visible
          Future.delayed(const Duration(milliseconds: 100), () {
            _ensureWelcomeMessageVisible();
          });
        }

        print('Created new conversation with ID: $_currentConversationId');
      }
    } catch (e) {
      print('Error creating new conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create new conversation: $e')),
      );
    }
  }
  // This method is now called through autoSaveCurrentConversation
  // Keeping implementation in case it's needed in future updates

  Future<void> _loadConversation(String conversationId, String title) async {
    // Show a loading indicator
    setState(() {
      _isLoading = true;
      // Clear any existing messages while loading
      _messages.clear();
    });

    // Add a safety timeout to ensure loading state doesn't get stuck
    Future.delayed(const Duration(seconds: 10), () {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading timed out. Please try again.')),
        );

        // If we timed out, add a welcome message so the user doesn't see an empty chat
        if (_messages.isEmpty) {
          _addWelcomeMessage();
          // Ensure the welcome message is visible
          Future.delayed(const Duration(milliseconds: 100), () {
            _ensureWelcomeMessageVisible();
          });
        }
      }
    });

    try {
      // Check if conversation exists
      bool exists = await _chatStorageService.conversationExists(
        conversationId,
      );
      if (!exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversation not found: $title')),
        );
        setState(() {
          _isLoading = false;
          // Add welcome message if no conversation found
          if (_messages.isEmpty) {
            _addWelcomeMessage();
          }
        });
        // Ensure the welcome message is visible
        if (_messages.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _ensureWelcomeMessageVisible();
          });
        }
        return;
      }

      final messages = await _chatStorageService.getMessages(conversationId);

      // Check if we got any messages back
      if (messages.isEmpty) {
        print(
          'No messages returned from storage for conversation: $conversationId',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation appears to be empty')),
        );
      }

      setState(() {
        // Clear again just in case anything was added while loading
        _messages.clear();
        _messages.addAll(messages);
        _currentConversationId = conversationId;
        _conversationTitle = title;
        _isNewConversation = false;
        _isLoading = false;
      });

      // Make sure to run this after setState to ensure messages are actually in the list
      Future.microtask(() {
        // Restore AI context with past messages
        _refreshAIMemory();

        // Ensure we scroll to show messages
        _scrollToBottom();
      });
    } catch (e) {
      print('Error loading conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversation: $e')),
      );
      setState(() {
        _isLoading = false;
        // Add welcome message if error occurred
        if (_messages.isEmpty) {
          _addWelcomeMessage();
        }
      });
      // Ensure the welcome message is visible
      if (_messages.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _ensureWelcomeMessageVisible();
        });
      }
    }
  }

  // Update the conversation title
  Future<void> _updateConversationTitle(String newTitle) async {
    if (_currentConversationId == null) return;

    try {
      await _chatStorageService.updateConversationTitle(
        _currentConversationId!,
        newTitle,
      );
      setState(() {
        _conversationTitle = newTitle;
      });
    } catch (e) {
      print('Error updating conversation title: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update conversation title: $e')),
      );
    }
  }

  // Send a hidden message to refresh the AI's memory with context
  Future<void> _refreshAIMemory() async {
    if (_messages.isEmpty) return;

    // Create a hidden system prompt to refresh the AI's memory with context
    // We're not adding this to the UI, just making a request
    try {
      // Take up to 5 most recent messages for context
      final List<Message> recentMessages = [];

      // Convert dynamic messages to Message objects
      for (var i = max(0, _messages.length - 5); i < _messages.length; i++) {
        recentMessages.add(_messages[i]);
      }

      // Use an invisible query to refresh the context
      await _chatbotService!.sendMessage(
        "Refresh your memory with the conversation context. Don't reply to this message.",
        recentMessages,
      );

      // Now the AI has context from previous messages
      print('AI memory refreshed with ${recentMessages.length} messages');
    } catch (e) {
      print('Error refreshing AI memory: $e');
    }
  }

  void _showRenameDialog() {
    final TextEditingController titleController = TextEditingController(
      text: _conversationTitle,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Rename Conversation',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Conversation Title',
                hintText: 'Enter a title for this conversation',
                labelStyle: TextStyle(color: Colors.blue.shade600),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
              TextButton(
                onPressed: () {
                  final newTitle = titleController.text.trim();
                  if (newTitle.isNotEmpty) {
                    _updateConversationTitle(newTitle);
                  }
                  Navigator.pop(context);
                },
                child: Text(
                  'Save',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
    );
  }

  void _navigateToConversationList() async {
    // Only save current conversation if there are user messages
    if (_messages.length >= 2 &&
        _hasUserMessages() &&
        _currentConversationId == null) {
      await _autoSaveCurrentConversation();
    }

    // Navigate to conversation list page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ConversationListPage(
              onConversationSelected: (id, title) {
                _loadConversation(id, title);
              },
            ),
      ),
    );

    // Handle result from conversation list page if needed
    if (result != null && result is Map<String, dynamic>) {
      if (result.containsKey('action') && result['action'] == 'new') {
        _createNewConversation();
      } else if (result.containsKey('id') && result.containsKey('title')) {
        _loadConversation(result['id'], result['title']);
      }
    }
  }

  // This method is now only used for manually triggered saves
  // It doesn't create new conversations anymore - that's handled in _sendMessage
  Future<void> _autoSaveCurrentConversation() async {
    // Only auto-save if we have messages AND a valid conversation ID
    if (_messages.isNotEmpty &&
        _currentConversationId != null &&
        _hasUserMessages()) {
      try {
        print(
          "Auto-saving messages to existing conversation: $_currentConversationId",
        );
        await _chatStorageService.saveMessages(
          _currentConversationId!,
          _messages,
        );
        _isNewConversation = false;
      } catch (e) {
        // Log the error but don't show UI notification for auto-save
        print('Error in auto-save: $e');
      }
    } else {
      print("Auto-save skipped - No conversation ID or no user messages");
    }
  }

  // Helper method to check if there are any user messages
  bool _hasUserMessages() {
    return _messages.any((message) => message.isUser);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Container(
              decoration: BoxDecoration(
                color:
                    Theme.of(context).appBarTheme.backgroundColor ??
                    Colors.white, // Or a specific color for your app bar
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.blue.withOpacity(0.1), // Subtle shadow color
                    spreadRadius: 0, // No spread, just blur
                    blurRadius:
                        15, // Adjust for desired blur intensity of the shadow
                    offset: const Offset(
                      0,
                      1,
                    ), // Shadow primarily below the app bar
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
                titleSpacing: 4, // Reduce spacing to make more room
                title: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 150,
                  ), // Constrain the width of the title
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main title - always LawLink AI
                      ShaderMask(
                        shaderCallback:
                            (bounds) => LinearGradient(
                              colors: [
                                Colors.blue.shade800,
                                Colors.blue.shade300,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                        child: const Text(
                          'LawLink AI',
                          style: TextStyle(
                            fontSize: 18, // Slightly smaller font size
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow:
                              TextOverflow
                                  .ellipsis, // Prevent text from overflowing
                        ),
                      ),
                      // Subtitle - conversation title (if in a saved conversation)
                      if (_currentConversationId != null && !_isNewConversation)
                        GestureDetector(
                          onTap: () {
                            // Show dialog to rename conversation
                            _showRenameDialog();
                          },
                          child: Text(
                            _conversationTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.blue.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  // Light/Dark mode toggle
                  IconButton(
                    icon: const Icon(Icons.light_mode),
                    tooltip: 'Toggle Light Mode',
                    color: Colors.blue.shade700, // Ensure consistent blue color
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
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                  ),

                  // New conversation button
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'New Conversation',
                    onPressed: _createNewConversation,
                  ),

                  // View conversations button
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: 'Conversation History',
                    onPressed: () => _navigateToConversationList(),
                  ),

                  // Language Selector
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
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
                      dropdownColor:
                          Colors.white, // White dropdown menu background
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
                              itemCount:
                                  _messages.length + (_isProcessing ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Show loading indicator for AI response
                                if (_isProcessing &&
                                    index == _messages.length) {
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
        ), // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.7),
            child: Center(
              child: Card(
                elevation: 4,
                color: Colors.white,
                shadowColor: Colors.blue.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.blue.shade100, width: 0.5),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue[500]!,
                        ),
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "Loading conversation...",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
