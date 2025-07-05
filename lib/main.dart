import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:lawlink/screens/auth_wrapper.dart';
import 'package:lawlink/screens/login_page.dart';
import 'package:lawlink/screens/signup_page.dart';
import 'package:lawlink/screens/main_page.dart';
import 'package:lawlink/screens/user_profile_page.dart';
import 'package:lawlink/screens/legal_procedures_page.dart';
import 'package:lawlink/screens/consumer_quiz_page.dart';
import 'package:lawlink/screens/quiz_menu_page.dart';
import 'package:lawlink/screens/leaderboard_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:lawlink/services/language_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lawlink/services/enhanced_notification_service.dart';
import 'package:lawlink/services/navigation_service.dart';
import 'package:lawlink/services/background_chat_service.dart';
import 'package:lawlink/services/chatbot_initialization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service
  try {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
  } catch (e) {
    print('Notification service initialization failed: $e');
  }

  // Initialize background chat service
  try {
    await BackgroundChatService.initialize();
  } catch (e) {
    print('Background chat service initialization failed: $e');
  }

  // Pre-initialize chatbot service (non-blocking)
  ChatbotInitializationService.initializeAsync()
      .then((success) {
        print('Chatbot initialization ${success ? 'completed' : 'failed'}');
      })
      .catchError((e) {
        print('Chatbot initialization error: $e');
      });

  runApp(
    ChangeNotifierProvider(
      create: (context) => LanguageService(),
      child: const LegalQuizGame(),
    ),
  );
}

class LegalQuizGame extends StatelessWidget {
  const LegalQuizGame({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return MaterialApp(
          title: 'LawLink',
          theme: ThemeData(primarySwatch: Colors.blue),
          home: const AuthWrapper(),
          navigatorKey: NavigationService.navigatorKey,
          locale: languageService.currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('si')],
          routes: {
            '/login': (context) => const LoginPage(),
            '/register': (context) => const SignUpPage(),
            '/home': (context) => const MainPage(),
            '/profile': (context) => const UserProfilePage(),
            '/quiz': (context) => const QuizMenuPage(),
            '/quiz/consumer': (context) => const ConsumerQuizPage(),
            '/procedures': (context) => const LegalProceduresPage(),
            '/leaderboard': (context) => const LeaderboardPage(),
          },
        );
      },
    );
  }
}
