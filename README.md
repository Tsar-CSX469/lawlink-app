# LawLink - Sri Lankan Legal Education Platform

<div align="center">
  <img src="assets/images/logo.png" alt="LawLink Logo" width="200"/>
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.7+-blue.svg)](https://flutter.dev/)
  [![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com/)
  [![AI Powered](https://img.shields.io/badge/AI%20Powered-Gemini-green.svg)](https://ai.google.dev/)
</div>

## 📖 Overview

LawLink is a comprehensive Flutter-based mobile application designed to make Sri Lankan law accessible and engaging for everyone. The app combines interactive learning, legal document management, AI-powered assistance, and procedural guidance to create a complete legal education platform.

## ✨ Features

### 🎯 Core Features

- **📚 Interactive Quiz System**: Test your knowledge of Sri Lankan laws with comprehensive quizzes
- **📖 Law Library**: Access and manage legal documents and acts
- **🤖 AI-Powered Chatbot**: Get instant legal guidance using Google's Gemini AI
- **📋 Legal Procedures**: Step-by-step guidance for common legal processes
- **🏆 Leaderboard System**: Compete with other users and track your progress
- **👤 User Authentication**: Secure login with email/password or Google Sign-In
- **📱 Cross-Platform**: Works on iOS, Android, Web, Windows, macOS, and Linux

### 🚀 Advanced Features

- **🎤 Voice Interaction**: Speak to the AI chatbot and receive voice responses
- **📄 Document Analysis**: Upload and analyze legal documents (PDF, DOC, DOCX, TXT)
- **🖼️ Image Analysis**: Upload images of legal documents for AI analysis
- **📍 Location Services**: Get location-based legal information
- **📊 Progress Tracking**: Monitor your learning progress and quiz scores
- **🔔 Real-time Updates**: Live leaderboard and user activity tracking

## 🛠️ Technology Stack

- **Frontend**: Flutter 3.7+
- **Backend**: Firebase (Firestore, Authentication)
- **AI Services**: Google Generative AI (Gemini)
- **Voice Services**: Speech-to-Text, Text-to-Speech
- **File Handling**: PDF processing, document parsing
- **State Management**: Flutter's built-in state management
- **UI Framework**: Material Design 3

## 📱 Screenshots

<div align="center">
  <img src="assets/images/screenshot1.png" alt="Main Dashboard" width="200"/>
  <img src="assets/images/screenshot2.png" alt="Quiz Interface" width="200"/>
  <img src="assets/images/screenshot3.png" alt="AI Chatbot" width="200"/>
  <img src="assets/images/screenshot4.png" alt="Law Library" width="200"/>
</div>

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.7.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / VS Code
- Firebase project setup
- Google AI API key

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/lawlink-frontend.git
   cd lawlink-frontend
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password and Google Sign-In)
   - Enable Firestore Database
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the respective platform folders

4. **Set up Google AI API**
   - Get your API key from [Google AI Studio](https://aistudio.google.com/)
   - Update the API key in `lib/services/chatbot_service.dart`

5. **Configure environment variables**
   - Create a `.env` file in the root directory
   - Add your API keys and configuration

6. **Run the app**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── act_list_page.dart        # Law library interface
├── add_act_page.dart         # Add new legal documents
├── screens/                  # App screens
│   ├── main_page.dart        # Dashboard
│   ├── auth_wrapper.dart     # Authentication routing
│   ├── login_page.dart       # Login screen
│   ├── signup_page.dart      # Registration screen
│   ├── user_profile_page.dart # User profile
│   ├── quiz_menu_page.dart   # Quiz selection
│   ├── consumer_quiz_page.dart # Quiz interface
│   ├── leaderboard_page.dart # Leaderboard
│   ├── chatbot_page.dart     # AI chatbot interface
│   ├── legal_procedures_page.dart # Legal procedures
│   └── procedures_page.dart  # Procedure details
├── services/                 # Business logic
│   ├── auth_service.dart     # Authentication service
│   ├── chatbot_service.dart  # AI chatbot service
│   ├── elevenlabs_service.dart # Voice synthesis
│   └── location_service.dart # Location services
└── widgets/                  # Reusable components
    └── floating_chatbot_button.dart # Chatbot access button
```

## 🔧 Configuration

### Firebase Setup

1. **Authentication**
   - Enable Email/Password authentication
   - Configure Google Sign-In
   - Set up user data collection in Firestore

2. **Firestore Database**
   - Create collections for users, quizzes, acts, and leaderboard
   - Set up security rules for data access

3. **Storage** (if needed)
   - Configure Firebase Storage for document uploads

### AI Configuration

1. **Google AI API**
   - Get API key from Google AI Studio
   - Update the key in `chatbot_service.dart`
   - Configure model parameters for optimal responses

2. **Voice Services**
   - Configure speech-to-text permissions
   - Set up text-to-speech parameters

## 📖 Usage Guide

### For Users

1. **Getting Started**
   - Download and install the app
   - Create an account or sign in with Google
   - Complete your profile setup

2. **Taking Quizzes**
   - Navigate to "Quiz Game" from the main menu
   - Select a quiz category
   - Answer questions and review explanations
   - Check your score and compare with others

3. **Using the AI Chatbot**
   - Tap the floating chat button on any screen
   - Ask legal questions in text or voice
   - Upload documents for analysis
   - Get instant legal guidance

4. **Accessing Legal Documents**
   - Go to "Law Library" to browse legal acts
   - Search for specific documents
   - Add new documents to your collection

5. **Learning Legal Procedures**
   - Visit "Procedures" section
   - Follow step-by-step guides
   - Get detailed explanations for each step

### For Developers

1. **Adding New Features**
   - Follow Flutter best practices
   - Use the existing service architecture
   - Maintain consistent UI/UX patterns

2. **Extending AI Capabilities**
   - Modify `chatbot_service.dart` for new AI features
   - Add new document analysis capabilities
   - Implement additional voice features

3. **Database Management**
   - Use Firestore for data persistence
   - Follow the established data models
   - Implement proper error handling

## 🔒 Security Features

- **Authentication**: Secure user authentication with Firebase
- **Data Protection**: Encrypted data transmission
- **Permission Management**: Granular app permissions
- **API Security**: Secure API key management
- **Input Validation**: Comprehensive input sanitization

## 🧪 Testing

### Manual Testing Checklist

- [ ] User registration and login
- [ ] Google Sign-In functionality
- [ ] Quiz taking and scoring
- [ ] AI chatbot responses
- [ ] Document upload and analysis
- [ ] Voice recording and playback
- [ ] Leaderboard functionality
- [ ] Cross-platform compatibility

### Automated Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run widget tests
flutter test test/widget_test.dart
```

## 🚀 Deployment

### Android

1. **Build APK**
   ```bash
   flutter build apk --release
   ```

2. **Build App Bundle**
   ```bash
   flutter build appbundle --release
   ```

### iOS

1. **Build for iOS**
   ```bash
   flutter build ios --release
   ```

2. **Archive and upload to App Store Connect**

### Web

1. **Build for web**
   ```bash
   flutter build web --release
   ```

2. **Deploy to hosting service**

## 📊 Performance

- **App Size**: Optimized for minimal download size
- **Loading Times**: Fast startup and navigation
- **Memory Usage**: Efficient memory management
- **Battery Life**: Optimized for extended use
- **Network Usage**: Minimal data consumption

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow Flutter coding conventions
- Write comprehensive tests
- Update documentation for new features
- Ensure cross-platform compatibility
- Maintain accessibility standards

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flutter Team** for the amazing framework
- **Firebase** for backend services
- **Google AI** for Gemini integration
- **Sri Lankan Legal Community** for domain expertise
- **Open Source Contributors** for various packages

## 📞 Support

- **Email**: support@lawlink.com
- **Documentation**: [docs.lawlink.com](https://docs.lawlink.com)
- **Issues**: [GitHub Issues](https://github.com/yourusername/lawlink-frontend/issues)
- **Discord**: [LawLink Community](https://discord.gg/lawlink)

## 🔄 Version History

- **v1.0.0** - Initial release with core features
- **v1.1.0** - Added AI chatbot functionality
- **v1.2.0** - Enhanced voice features and document analysis
- **v1.3.0** - Improved UI/UX and performance optimizations

---

<div align="center">
  <p>Made with ❤️ for the Sri Lankan legal community</p>
  <p>Empowering legal education through technology</p>
</div>
