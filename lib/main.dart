// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===== DATA MODELS AND PROVIDERS =====
class Question {
  final String questionText;
  final List<Answer> answers;
  final String? explanation;
  final String difficulty;

  Question({
    required this.questionText,
    required this.answers,
    this.explanation,
    required this.difficulty,
  });
}

class Answer {
  final String text;
  final bool isCorrect;
  Answer({required this.text, required this.isCorrect});
}

class LeaderboardEntry {
  final String userId;
  final String name;
  final int score;

  LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.score,
  });
}

class UserProvider with ChangeNotifier {
  String _currentUserId = '';
  String _currentUserName = 'Guest';
  int _score = 0;
  List<LeaderboardEntry> _leaderboardData = [];
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  String get currentUserId => _currentUserId;
  String get currentUserName => _currentUserName;
  int get score => _score;
  List<LeaderboardEntry> get leaderboardData {
    _leaderboardData.sort((a, b) => b.score.compareTo(a.score));
    return _leaderboardData;
  }

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;

  Future<void> initUser() async {
    _isInitialized = false;
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _currentUserId = prefs.getString('userId') ?? 'guest_user';
    _currentUserName = prefs.getString('userName') ?? 'Guest';
    if (_isLoggedIn) {
      // Simulate loading initial leaderboard data for a logged-in user
      _leaderboardData = [
        LeaderboardEntry(userId: 'user1', name: 'Alice', score: 120),
        LeaderboardEntry(userId: 'user2', name: 'Bob', score: 95),
        LeaderboardEntry(userId: 'user3', name: 'Charlie', score: 150),
        LeaderboardEntry(
          userId: _currentUserId,
          name: _currentUserName,
          score: _score,
        ),
      ];
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> login(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = true;
    _currentUserId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentUserName = userName;
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', _currentUserId);
    await prefs.setString('userName', _currentUserName);
    // Add the new user to the simulated leaderboard
    _leaderboardData.add(
      LeaderboardEntry(
        userId: _currentUserId,
        name: _currentUserName,
        score: 0,
      ),
    );
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = false;
    _currentUserId = 'guest_user';
    _currentUserName = 'Guest';
    _score = 0;
    _leaderboardData.removeWhere((entry) => entry.userId == currentUserId);
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    await prefs.remove('userName');
    notifyListeners();
  }

  void updateScore(int score) {
    _score = score;
    // Update the score on the leaderboard
    final index = _leaderboardData.indexWhere(
      (e) => e.userId == _currentUserId,
    );
    if (index != -1) {
      _leaderboardData[index] = LeaderboardEntry(
        userId: _currentUserId,
        name: _currentUserName,
        score: _score,
      );
    }
    notifyListeners();
  }

  void updateUserName(String newName) {
    _currentUserName = newName;
    final index = _leaderboardData.indexWhere(
      (e) => e.userId == _currentUserId,
    );
    if (index != -1) {
      _leaderboardData[index] = LeaderboardEntry(
        userId: _currentUserId,
        name: newName,
        score: _score,
      );
    }
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('userName', newName);
    });
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }
}

// ===== QUIZ DATA =====
const List<Map<String, Object>> dummyQuestions = [
  {
    'questionText': 'What is the capital of France?',
    'answers': [
      {'text': 'Berlin', 'isCorrect': false},
      {'text': 'Madrid', 'isCorrect': false},
      {'text': 'Paris', 'isCorrect': true},
      {'text': 'Rome', 'isCorrect': false},
    ],
    'explanation': 'Paris is the capital and most populous city of France.',
    'difficulty': 'easy',
  },
  {
    'questionText': 'Which planet is known as the "Red Planet"?',
    'answers': [
      {'text': 'Earth', 'isCorrect': false},
      {'text': 'Mars', 'isCorrect': true},
      {'text': 'Jupiter', 'isCorrect': false},
      {'text': 'Venus', 'isCorrect': false},
    ],
    'explanation':
        'Mars is often called the Red Planet because of its reddish appearance.',
    'difficulty': 'easy',
  },
  {
    'questionText': 'What is the largest ocean on Earth?',
    'answers': [
      {'text': 'Atlantic Ocean', 'isCorrect': false},
      {'text': 'Indian Ocean', 'isCorrect': false},
      {'text': 'Arctic Ocean', 'isCorrect': false},
      {'text': 'Pacific Ocean', 'isCorrect': true},
    ],
    'explanation':
        'The Pacific Ocean is the largest and deepest of Earth\'s five oceans.',
    'difficulty': 'medium',
  },
  {
    'questionText': 'Who wrote "To Kill a Mockingbird"?',
    'answers': [
      {'text': 'J.K. Rowling', 'isCorrect': false},
      {'text': 'Harper Lee', 'isCorrect': true},
      {'text': 'Stephen King', 'isCorrect': false},
      {'text': 'Mark Twain', 'isCorrect': false},
    ],
    'explanation':
        'Harper Lee\'s "To Kill a Mockingbird" won the Pulitzer Prize in 1961.',
    'difficulty': 'hard',
  },
];

// ===== MAIN APP WIDGET =====
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..initUser()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const QuizApp(),
    ),
  );
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    return MaterialApp(
      title: 'Quiz Quest',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal,
          secondary: Colors.amber,
          tertiary: Colors.purple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal.shade200,
          secondary: Colors.amber.shade200,
          tertiary: Colors.purple.shade200,
          brightness: Brightness.dark,
        ),
      ),
      home: userProvider.isInitialized
          ? (userProvider.isLoggedIn ? const MainScreen() : const AuthScreen())
          : const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading Quiz Quest...'),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _widgetOptions = <Widget>[
    WelcomeScreen(),
    CategoryScreen(),
    SettingsScreen(),
    LeaderboardScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quizzes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

// ===== AUTHENTICATION SCREEN =====
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to Quiz Quest!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Enter Your Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_nameController.text.isNotEmpty) {
                    Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).login(_nameController.text);
                  }
                },
                child: const Text('Start Playing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== APP SCREENS (PAGES) =====
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context).currentUserName;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Hero(
                tag: 'logo',
                child: Icon(Icons.emoji_events, size: 150, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, $userName!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Test Your Knowledge on Quiz Quest!',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final easyQuestions = dummyQuestions
        .where((q) => q['difficulty'] == 'easy')
        .toList();
    final mediumQuestions = dummyQuestions
        .where((q) => q['difficulty'] == 'medium')
        .toList();
    final hardQuestions = dummyQuestions
        .where((q) => q['difficulty'] == 'hard')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Quiz Difficulty'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDifficultyCard(context, 'Easy', Colors.green, easyQuestions),
            _buildDifficultyCard(
              context,
              'Medium',
              Colors.orange,
              mediumQuestions,
            ),
            _buildDifficultyCard(context, 'Hard', Colors.red, hardQuestions),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuizCreationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.create),
              label: const Text('Create Your Own Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(
    BuildContext context,
    String title,
    Color color,
    List<Map<String, Object>> questions,
  ) {
    if (questions.isEmpty) {
      return Container();
    }
    final List<Question> quizQuestions = questions.map((q) {
      return Question(
        questionText: q['questionText'] as String,
        answers: (q['answers'] as List)
            .map(
              (a) => Answer(
                text: a['text'] as String,
                isCorrect: a['isCorrect'] as bool,
              ),
            )
            .toList(),
        explanation: q['explanation'] as String?,
        difficulty: q['difficulty'] as String,
      );
    }).toList();

    return Card(
      color: color.withOpacity(0.1),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  QuizScreen(category: title, questions: quizQuestions),
            ),
          );
        },
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String category;
  final List<Question> questions;
  const QuizScreen({
    super.key,
    required this.category,
    required this.questions,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _questionIndex = 0;
  int _score = 0;
  bool _isAnswered = false;
  late Timer _timer;
  static const int quizDuration = 100;
  int _remainingTime = quizDuration;

  final Map<bool, String> feedbackMessages = {
    true: 'Brilliant!',
    false: 'Don\'t give up! Failure is a stepping stone to success.',
  };

  @override
  void initState() {
    super.initState();
    _startTimer();
    widget.questions.shuffle();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        if (mounted) {
          setState(() {
            _remainingTime--;
          });
        }
      } else {
        _timer.cancel();
        _finishQuiz();
      }
    });
  }

  void _finishQuiz() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            score: _score,
            totalQuestions: widget.questions.length,
          ),
        ),
      );
    }
  }

  void _answerQuestion(bool isCorrect) {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true;
      if (isCorrect) {
        _score++;
      }
    });

    // Show a snackbar with the personalized feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          feedbackMessages[isCorrect]!,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isCorrect ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          if (_questionIndex < widget.questions.length - 1) {
            _questionIndex++;
            _isAnswered = false;
          } else {
            _timer.cancel();
            _finishQuiz();
          }
        });
      }
    });
  }

  String get _formattedTime {
    final minutes = _remainingTime ~/ 60;
    final seconds = _remainingTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_remainingTime > quizDuration * 0.5) {
      return Colors.green;
    } else if (_remainingTime > quizDuration * 0.2) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} Quiz'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Chip(
              label: Text(
                _formattedTime,
                style: TextStyle(
                  color: _timerColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
      body: _questionIndex < widget.questions.length
          ? Quiz(
              questionData: widget.questions[_questionIndex],
              answerQuestion: _answerQuestion,
              isAnswered: _isAnswered,
            )
          : ResultScreen(
              score: _score,
              totalQuestions: widget.questions.length,
            ),
    );
  }
}

class Quiz extends StatefulWidget {
  final Question questionData;
  final Function(bool) answerQuestion;
  final bool isAnswered;
  const Quiz({
    super.key,
    required this.questionData,
    required this.answerQuestion,
    required this.isAnswered,
  });

  @override
  State<Quiz> createState() => _QuizState();
}

class _QuizState extends State<Quiz> with TickerProviderStateMixin {
  late AnimationController _questionController;
  late AnimationController _answerController;

  @override
  void initState() {
    super.initState();
    _questionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _answerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _startAnimations();
  }

  void _startAnimations() {
    _questionController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _answerController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant Quiz oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionData.questionText !=
        widget.questionData.questionText) {
      _questionController.reset();
      _answerController.reset();
      _startAnimations();
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionText = widget.questionData.questionText;
    final answers = widget.questionData.answers;
    final explanation = widget.questionData.explanation;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeTransition(
            opacity: _questionController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(_questionController),
              child: Card(
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    questionText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: answers.length,
              itemBuilder: (context, index) {
                final answer = answers[index];
                return FadeTransition(
                  opacity: _answerController,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: Offset(0, 0.5 + index * 0.2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _answerController,
                            curve: Curves.easeOut,
                          ),
                        ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: widget.isAnswered
                            ? null
                            : () => widget.answerQuestion(answer.isCorrect),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isAnswered
                              ? (answer.isCorrect
                                    ? Colors.green.withOpacity(0.7)
                                    : Colors.red.withOpacity(0.7))
                              : Theme.of(context).colorScheme.primary,
                          elevation: 3,
                        ),
                        child: Text(
                          answer.text,
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.isAnswered && explanation != null)
            FadeTransition(
              opacity: _answerController,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Card(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Explanation: $explanation',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  const ResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
  });
  String get _getRewardType {
    if (score == totalQuestions) {
      return 'master';
    } else if (score >= totalQuestions / 2) {
      return 'good';
    } else {
      return 'beginner';
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<UserProvider>(context, listen: false).updateScore(score);
    final String rewardType = _getRewardType;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                rewardType == 'master'
                    ? Icons.emoji_events
                    : Icons.check_circle,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              Text(
                'You scored $score out of $totalQuestions!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Go Home',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _nameController = TextEditingController(text: userProvider.currentUserName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateUserName() {
    if (_nameController.text.isNotEmpty) {
      Provider.of<UserProvider>(
        context,
        listen: false,
      ).updateUserName(_nameController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ListTile(
                title: const Text('Toggle Dark/Light Mode'),
                trailing: Switch(
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                ),
              ),
              const Divider(),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Change Your Name',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _updateUserName,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  userProvider.logout();
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final leaderboardData = userProvider.leaderboardData;
    final currentUserId = userProvider.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: leaderboardData.isEmpty
          ? const Center(child: Text('No scores to display yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: leaderboardData.length,
              itemBuilder: (context, index) {
                final entry = leaderboardData[index];
                final rank = index + 1;
                final isCurrentUser = entry.userId == currentUserId;

                return Card(
                  color: isCurrentUser
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : null,
                  elevation: isCurrentUser ? 8 : 4,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrentUser
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.primary,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      entry.name,
                      style: TextStyle(
                        fontWeight: isCurrentUser
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: Text(
                      'Score: ${entry.score}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class QuizCreationScreen extends StatefulWidget {
  const QuizCreationScreen({super.key});
  @override
  State<QuizCreationScreen> createState() => _QuizCreationScreenState();
}

class _QuizCreationScreenState extends State<QuizCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  List<QuestionData> _questions = [QuestionData()];
  String? _selectedDifficulty = 'easy';
  @override
  void dispose() {
    _categoryController.dispose();
    for (var q in _questions) {
      q.questionController.dispose();
      q.explanationController.dispose();
      for (var a in q.answers) {
        a.answerController.dispose();
      }
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(QuestionData());
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions.removeAt(index);
      });
    }
  }

  void _submitQuiz() {
    if (_formKey.currentState!.validate()) {
      final String category = _categoryController.text.trim();
      final List<Map<String, Object>> newQuestions = [];

      for (var q in _questions) {
        final List<Map<String, Object>> answers = [];
        for (var a in q.answers) {
          answers.add({
            'text': a.answerController.text.trim(),
            'isCorrect': a.isCorrect,
          });
        }
        newQuestions.add({
          'questionText': q.questionController.text.trim(),
          'answers': answers,
          'explanation': q.explanationController.text.trim(),
          'difficulty': _selectedDifficulty!,
        });
      }

      // This part would ideally save to a database. For this example, it's not implemented.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz created successfully! (Not saved persistently)'),
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a New Quiz'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Quiz Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['easy', 'medium', 'hard'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.toUpperCase()),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDifficulty = newValue;
                  });
                },
              ),
              const SizedBox(height: 20),
              ..._questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return QuestionBuilder(
                  key: ValueKey(index),
                  questionData: question,
                  onRemove: () => _removeQuestion(index),
                );
              }).toList(),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text('Add Question'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitQuiz,
                child: const Text('Create Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuestionBuilder extends StatefulWidget {
  final QuestionData questionData;
  final VoidCallback onRemove;

  const QuestionBuilder({
    super.key,
    required this.questionData,
    required this.onRemove,
  });

  @override
  State<QuestionBuilder> createState() => _QuestionBuilderState();
}

class _QuestionBuilderState extends State<QuestionBuilder> {
  void _addAnswer() {
    if (widget.questionData.answers.length < 4) {
      setState(() {
        widget.questionData.answers.add(AnswerData());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 answers per question.')),
      );
    }
  }

  void _removeAnswer(int index) {
    if (widget.questionData.answers.length > 2) {
      setState(() {
        widget.questionData.answers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.questionData.questionController,
                    decoration: InputDecoration(
                      labelText: 'Question',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a question.';
                      }
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: widget.questionData.explanationController,
              decoration: InputDecoration(
                labelText: 'Explanation (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Answers:', style: Theme.of(context).textTheme.titleSmall),
            ...widget.questionData.answers.asMap().entries.map((entry) {
              final index = entry.key;
              final answer = entry.value;
              return AnswerBuilder(
                key: ValueKey(answer),
                answerData: answer,
                onRemove: () => _removeAnswer(index),
                onToggleCorrect: (bool? value) {
                  if (value == true) {
                    for (var otherAnswer in widget.questionData.answers) {
                      if (otherAnswer != answer) {
                        otherAnswer.isCorrect = false;
                      }
                    }
                  }
                  setState(() {
                    answer.isCorrect = value!;
                  });
                },
                canRemove: widget.questionData.answers.length > 2,
              );
            }).toList(),
            const SizedBox(height: 10),
            if (widget.questionData.answers.length < 4)
              OutlinedButton.icon(
                onPressed: _addAnswer,
                icon: const Icon(Icons.add),
                label: const Text('Add Answer'),
              ),
          ],
        ),
      ),
    );
  }
}

class AnswerBuilder extends StatelessWidget {
  final AnswerData answerData;
  final VoidCallback onRemove;
  final Function(bool?) onToggleCorrect;
  final bool canRemove;

  const AnswerBuilder({
    super.key,
    required this.answerData,
    required this.onRemove,
    required this.onToggleCorrect,
    this.canRemove = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: answerData.answerController,
              decoration: InputDecoration(
                labelText: 'Answer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an answer.';
                }
                return null;
              },
            ),
          ),
          Checkbox(value: answerData.isCorrect, onChanged: onToggleCorrect),
          const Text('Correct'),
          if (canRemove)
            IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
        ],
      ),
    );
  }
}

class QuestionData {
  final TextEditingController questionController = TextEditingController();
  final TextEditingController explanationController = TextEditingController();
  final List<AnswerData> answers = [AnswerData(), AnswerData()];
}

class AnswerData {
  final TextEditingController answerController = TextEditingController();
  bool isCorrect = false;
}
