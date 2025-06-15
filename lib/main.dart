import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lawlink/screens/auth_wrapper.dart';
import 'package:lawlink/screens/login_page.dart';
import 'package:lawlink/screens/signup_page.dart';
import 'package:lawlink/screens/main_page.dart';
import 'package:lawlink/screens/user_profile_page.dart';
import 'package:lawlink/screens/quiz_page.dart';
import 'package:lawlink/screens/procedures_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LegalQuizGame());
}

class LegalQuizGame extends StatelessWidget {
  const LegalQuizGame({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LawLink',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const SignUpPage(),
        '/home': (context) => const MainPage(),
        '/profile': (context) => const UserProfilePage(),
        '/quiz': (context) => const QuizPage(),
        '/procedures': (context) => const ProceduresPage(),
      },
    );
  }
}
