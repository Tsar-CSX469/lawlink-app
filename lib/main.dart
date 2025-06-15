import 'package:flutter/material.dart';
import 'package:lawlink/act_list_page.dart'; // Import your Act List Page
import 'package:firebase_core/firebase_core.dart';
import 'package:lawlink/add_act_page.dart'; // Import your Add Act Page
import 'package:lawlink/widgets/floating_chatbot_button.dart';
import 'package:lawlink/screens/auth_wrapper.dart';
import 'package:lawlink/screens/login_page.dart';
import 'package:lawlink/screens/register_page.dart';
import 'package:lawlink/screens/user_profile_page.dart';
import 'package:lawlink/services/auth_service.dart';
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
      title: 'Sri Lanka Law Quiz',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const QuizPage(),
        '/profile': (context) => const UserProfilePage(),
      },
    );
  }
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  QuizPageState createState() => QuizPageState();
}

class QuizPageState extends State<QuizPage> {
  // Example questions (replace with real legal content)
  final List<Map<String, Object>> _questions = [
    {
      'question':
          'You buy a phone with a 1-year warranty. It stops working after 2 months. What should you do?',
      'answers': [
        {'text': 'Ask for a free repair or replacement', 'correct': true},
        {'text': 'Buy a new phone', 'correct': false},
        {'text': 'Do nothing', 'correct': false},
      ],
      'explanation':
          'Under Sri Lankan consumer law, you have the right to a free repair or replacement during the warranty period.',
    },
    {
      'question': 'A shop refuses to give you a receipt. Is this legal?',
      'answers': [
        {'text': 'Yes', 'correct': false},
        {'text': 'No', 'correct': true},
      ],
      'explanation':
          'According to the Consumer Affairs Authority Act, shops must provide receipts for purchases.',
    },
    // Add more questions as needed
  ];

  int _currentQuestion = 0;
  bool _answered = false;
  bool _isCorrect = false;
  String _explanation = '';

  void _answerQuestion(bool correct, String explanation) {
    setState(() {
      _answered = true;
      _isCorrect = correct;
      _explanation = explanation;
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestion = (_currentQuestion + 1) % _questions.length;
      _answered = false;
      _isCorrect = false;
      _explanation = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestion];
    return ChatbotWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sri Lanka Law Quiz'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Profile',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfilePage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.menu_book),
              tooltip: 'View Acts',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ActListPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                final authService = AuthService();
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                question['question'] as String,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ...(question['answers'] as List<Map<String, Object>>).map((
                answer,
              ) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ElevatedButton(
                    onPressed:
                        _answered
                            ? null
                            : () => _answerQuestion(
                              answer['correct'] as bool,
                              question['explanation'] as String,
                            ),
                    child: Text(answer['text'] as String),
                  ),
                );
              }),
              const SizedBox(height: 24),
              if (_answered)
                Column(
                  children: [
                    Text(
                      _isCorrect ? 'Correct!' : 'Incorrect.',
                      style: TextStyle(
                        color: _isCorrect ? Colors.green : Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_explanation),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              // Optional: Add a button at the bottom as well
              ElevatedButton.icon(
                icon: const Icon(Icons.menu_book),
                label: const Text('View Acts List'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ActListPage()),
                  );
                },
              ),
            ],
          ),
        ),
        // FloatingActionButton for adding new acts
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddActPage()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
