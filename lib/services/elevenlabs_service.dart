import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ElevenLabsService {
  static const String baseUrl = 'https://api.elevenlabs.io/v1';
  late final String apiKey;
  late final String defaultVoiceId;

  ElevenLabsService() {
    // Get API key and voice ID from environment variables
    apiKey =
        dotenv.env['ELEVENLABS_API_KEY'] ??
        'sk_e7cfa2256f45512163bb2706416ddbaf2f343f30ab6f8f7d';
    defaultVoiceId =
        dotenv.env['ELEVENLABS_VOICE_ID'] ??
        '21m00Tcm4TlvDq8ikWAM'; // Rachel voice
  }

  // List of available voices with their IDs
  static final Map<String, String> availableVoices = {
    'Rachel (female)': '21m00Tcm4TlvDq8ikWAM', // Professional female voice
    'Domi (female)': 'AZnzlk1XvdvUeBnXmlld', // Casual female voice
    'Antoni (male)': 'ErXwobaYiN019PkySvjV', // Professional male voice
    'Josh (male)': 'TxGEqnHWrfWFTfGW9XjX', // Casual male voice
    'Arnold (male)': 'VR6AewLTigWG4xSOukaG', // Deep male voice
  };

  /// Gets a list of all available voices from ElevenLabs
  Future<List<Map<String, dynamic>>> getVoices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/voices'),
        headers: {'xi-api-key': apiKey, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['voices']);
      } else {
        print('Failed to get voices: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting voices: $e');
      return [];
    }
  }

  /// Converts text to speech using the ElevenLabs API and returns the path to the audio file
  Future<String?> textToSpeech(String text, {String? voiceId}) async {
    try {
      // Use default voice if none provided
      final voice = voiceId ?? defaultVoiceId;

      // Prepare request body
      final Map<String, dynamic> body = {
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
          'style': 0.0,
          'use_speaker_boost': true,
        },
      };

      // Make API request
      final response = await http.post(
        Uri.parse('$baseUrl/text-to-speech/$voice'),
        headers: {'xi-api-key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // Check if the request was successful
      if (response.statusCode == 200) {
        // Save audio to file
        return await _saveAudioToFile(response.bodyBytes);
      } else {
        print(
          'Failed to generate speech: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Error generating speech: $e');
      return null;
    }
  }

  /// Saves the audio bytes to a file and returns the file path
  Future<String?> _saveAudioToFile(Uint8List audioBytes) async {
    try {
      // For web, we can't save to a file, so return null
      if (kIsWeb) {
        print('File saving not supported on web');
        return null;
      }

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/elevenlabs_${DateTime.now().millisecondsSinceEpoch}.mp3';

      // Write the audio bytes to a file
      final file = File(filePath);
      await file.writeAsBytes(audioBytes);

      return filePath;
    } catch (e) {
      print('Error saving audio file: $e');
      return null;
    }
  }
}
