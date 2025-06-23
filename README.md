# LawLink - Sri Lankan Legal Education Platform

## Executive Summary

LawLink is a comprehensive Flutter-based legal education platform designed to democratize access to Sri Lankan legal knowledge. The application leverages cutting-edge artificial intelligence to provide interactive learning experiences, document analysis capabilities, and personalized legal assistance. Built with modern development practices, LawLink serves as a bridge between complex legal information and everyday users.

## Project Overview

### Purpose
The primary objective of LawLink is to address the legal literacy gap in Sri Lanka by providing an accessible, user-friendly platform for legal education and consultation. The application combines traditional learning methodologies with advanced AI technologies to create an engaging educational experience.

### Target Audience
- Legal students and professionals
- General public seeking legal knowledge
- Educational institutions
- Legal aid organizations
- Government agencies

## Technical Architecture

### Technology Stack

#### Frontend Framework
- **Platform**: Flutter 3.7+
- **Language**: Dart
- **UI Framework**: Material Design 3
- **State Management**: Provider pattern with reactive programming

#### Backend Services
- **Authentication**: Firebase Authentication
- **Database**: Cloud Firestore
- **AI Engine**: Google Generative AI (Gemini Pro)
- **Text-to-Speech**: ElevenLabs AI Voice API
- **File Processing**: Custom document analysis pipeline
- **Storage**: Firebase Cloud Storage

#### Key Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.5
  cloud_firestore: ^5.6.8
  google_generative_ai: ^0.4.3
  speech_to_text: ^7.0.0
  file_picker: ^10.2.0
  dash_chat_2: ^0.0.21
  flutter_chat_ui: ^1.6.12
  read_pdf_text: ^0.3.1
  path_provider: ^2.1.2
  google_sign_in: ^6.2.1
  audioplayers: ^5.2.1
  record: ^5.0.4
  http: ^1.4.0
  flutter_dotenv: ^5.1.0
```

## Core Features

### 1. Interactive Legal Assessment System
- **Dynamic Quiz Engine**: Comprehensive consumer law evaluation
- **Adaptive Questioning**: Difficulty-based question selection
- **Progress Tracking**: Individual performance analytics
- **Competitive Elements**: Leaderboard and achievement system

### 2. AI-Powered Legal Assistant
- **Multi-modal Interface**: Text, voice, and document input
- **Natural Language Processing**: Context-aware legal queries
- **Document Intelligence**: PDF, DOC, DOCX analysis
- **Voice Interaction**: Speech-to-text and ElevenLabs AI text-to-speech capabilities

### 3. Legal Document Management
- **Comprehensive Library**: Access to legal acts and procedures
- **Search Functionality**: Advanced document retrieval
- **Content Analysis**: AI-powered document interpretation
- **User Annotations**: Personal note-taking capabilities

### 4. User Management System
- **Secure Authentication**: Firebase Auth with Google Sign-In
- **Profile Management**: Comprehensive user profiles
- **Data Privacy**: GDPR-compliant data handling
- **Session Management**: Secure login/logout procedures

## Implementation Details

### Project Structure
```
lib/
├── main.dart                 # Application entry point
├── firebase_options.dart     # Firebase configuration
├── screens/                  # User interface components
│   ├── auth_wrapper.dart     # Authentication state management
│   ├── login_page.dart       # User authentication interface
│   ├── signup_page.dart      # User registration interface
│   ├── main_page.dart        # Primary dashboard
│   ├── user_profile_page.dart # User profile management
│   ├── quiz_menu_page.dart   # Assessment selection interface
│   ├── consumer_quiz_page.dart # Consumer law assessment
│   ├── legal_procedures_page.dart # Legal document browser
│   ├── leaderboard_page.dart # Competitive rankings
│   └── chatbot_page.dart     # AI assistant interface
├── services/                 # Business logic implementation
│   ├── auth_service.dart     # Authentication management
│   ├── chatbot_service.dart  # AI integration service
│   ├── location_service.dart # Location-based features
│   └── elevenlabs_service.dart # ElevenLabs text-to-speech service
└── widgets/                  # Reusable UI components
    └── floating_chatbot_button.dart # Global AI access
```

### Authentication Implementation
```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser != null) {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    }
    return null;
  }
}
```

### AI Integration Architecture
```dart
class ChatbotService {
  static const String _apiKey = 'YOUR_GOOGLE_AI_API_KEY';
  static final GenerativeModel _model = GenerativeModel(
    model: 'gemini-pro',
    apiKey: _apiKey,
  );
  
  Future<String> generateResponse(String prompt) async {
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    return response.text ?? 'No response generated';
  }
}
```

### ElevenLabs Text-to-Speech Integration
```dart
class ElevenLabsService {
  static const String _apiKey = 'YOUR_ELEVENLABS_API_KEY';
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  
  Future<String> textToSpeech(String text, String voiceId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/text-to-speech/$voiceId'),
      headers: {
        'Accept': 'audio/mpeg',
        'Content-Type': 'application/json',
        'xi-api-key': _apiKey,
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_monolingual_v1',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.5,
        },
      }),
    );
    
    if (response.statusCode == 200) {
      // Save audio file and return path
      return await _saveAudioFile(response.bodyBytes);
    } else {
      throw Exception('Failed to generate speech');
    }
  }
}
```

## Installation and Deployment

### Prerequisites
- Flutter SDK 3.7.0 or higher
- Dart SDK 3.7.0 or higher
- Firebase project with Authentication and Firestore enabled
- Google AI API key for chatbot functionality
- ElevenLabs API key for text-to-speech functionality

### Installation Procedure
```bash
# Repository cloning
git clone <repository-url>
cd lawlink-frontend

# Dependency installation
flutter pub get

# Environment configuration
cp .env.example .env
# Configure API keys in .env file

# Application execution
flutter run
```

### Configuration Requirements
1. **Firebase Project Setup**
   - Enable Email/Password authentication
   - Configure Google Sign-In provider
   - Initialize Firestore database
   - Set up security rules

2. **Google AI Integration**
   - Obtain API key from Google AI Studio
   - Configure chatbot service with API key
   - Test AI functionality

3. **ElevenLabs Integration**
   - Sign up for ElevenLabs account
   - Obtain API key from ElevenLabs dashboard
   - Configure text-to-speech service

4. **Environment Variables**
   ```env
   GOOGLE_AI_API_KEY=your_google_ai_api_key
   ELEVENLABS_API_KEY=your_elevenlabs_api_key
   ```

## Platform-Specific Setup

### Android Setup

#### Prerequisites
- Android Studio installed
- Android SDK (API level 21+)
- Java Development Kit (JDK) 11 or higher

#### Configuration Steps
1. **Firebase Configuration**
   ```bash
   # Download google-services.json from Firebase Console
   # Place in android/app/google-services.json
   ```

2. **Android Permissions**
   Add to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```

3. **Build Configuration**
   Update `android/app/build.gradle`:
   ```gradle
   android {
       compileSdkVersion 34
       defaultConfig {
           minSdkVersion 21
           targetSdkVersion 34
       }
   }
   ```

4. **Run on Android**
   ```bash
   # Connect Android device or start emulator
   flutter devices
   
   # Run the app
   flutter run
   
   # Build APK
   flutter build apk --release
   
   # Build App Bundle
   flutter build appbundle --release
   ```

### iOS Setup

#### Prerequisites
- macOS with Xcode 14.0 or higher
- iOS 12.0 or higher
- CocoaPods installed

#### Configuration Steps
1. **Firebase Configuration**
   ```bash
   # Download GoogleService-Info.plist from Firebase Console
   # Place in ios/Runner/GoogleService-Info.plist
   ```

2. **iOS Permissions**
   Add to `ios/Runner/Info.plist`:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>This app needs access to microphone for voice input</string>
   <key>NSCameraUsageDescription</key>
   <string>This app needs access to camera for document scanning</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>This app needs access to photo library for document upload</string>
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>This app needs access to location for local legal services</string>
   ```

3. **Pod Installation**
   ```bash
   cd ios
   pod install
   cd ..
   ```

4. **Run on iOS**
   ```bash
   # Open iOS Simulator or connect iPhone
   flutter devices
   
   # Run the app
   flutter run
   
   # Build for iOS
   flutter build ios --release
   ```

### Web Setup

#### Prerequisites
- Chrome, Firefox, or Safari browser
- Web server (optional for production)

#### Configuration Steps
1. **Web Configuration**
   ```bash
   # Enable web support
   flutter config --enable-web
   
   # Run on web
   flutter run -d chrome
   
   # Build for web
   flutter build web --release
   ```

## Deployment Specifications

### Build Commands
```bash
# Android deployment
flutter build apk --release
flutter build appbundle --release

# iOS deployment
flutter build ios --release

# Web deployment
flutter build web --release
```

### Platform Support Matrix
- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 12.0+
- **Web**: Chrome 90+, Firefox 88+, Safari 14+
- **Windows**: Windows 10+
- **macOS**: macOS 10.14+
- **Linux**: Ubuntu 18.04+

## License and Legal

### Third-Party Licenses
- **Flutter**: Apache License 2.0
- **Firebase**: Apache License 2.0
- **Google AI**: Google AI Terms of Service
- **ElevenLabs**: ElevenLabs Terms of Service
- **Dependencies**: Respective open-source licenses

---

**Document Version**: 1.0  
**Last Updated**: June 2025  
**Maintained By**: LawLink Development Team
