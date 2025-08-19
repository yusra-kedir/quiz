import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// --- Placeholder Provider Classes ---

class UserProvider with ChangeNotifier {
  final List<LeaderboardEntry> _leaderboardData = [
    LeaderboardEntry(userId: 'user1', name: 'Alice', score: 1200),
    LeaderboardEntry(userId: 'user2', name: 'Bob', score: 1150),
    LeaderboardEntry(userId: 'user3', name: 'Charlie', score: 1050),
    LeaderboardEntry(userId: 'user4', name: 'Diana', score: 900),
    LeaderboardEntry(userId: 'current_user_id', name: 'You', score: 950),
  ];
  String? _currentUserId;

  String? get currentUserId => _currentUserId;
  User? get currentUser =>
      _currentUserId != null ? User(id: _currentUserId!, name: 'You') : null;

  List<LeaderboardEntry> get leaderboardData {
    _leaderboardData.sort((a, b) => b.score.compareTo(a.score));
    return _leaderboardData;
  }

  void setCurrentUser(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  void updateScore(int score) {
    final userIndex = _leaderboardData.indexWhere(
      (entry) => entry.userId == _currentUserId,
    );
    if (userIndex != -1) {
      _leaderboardData[userIndex] = LeaderboardEntry(
        userId: _currentUserId!,
        name: _leaderboardData[userIndex].name,
        score: _leaderboardData[userIndex].score + score * 10,
      );
      notifyListeners();
    }
  }

  void logout() {
    _currentUserId = null;
    notifyListeners();
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }
}

class UserQuizProvider with ChangeNotifier {
  final List<Map<String, List<Map<String, Object>>>> _userQuizzes = [];
  List<Map<String, List<Map<String, Object>>>> get userQuizzes => _userQuizzes;

  void addQuiz(String category, List<Map<String, Object>> questions) {
    _userQuizzes.add({category: questions});
    notifyListeners();
  }
}

class ApiProvider with ChangeNotifier {
  Future<List<Map<String, Object>>?> fetchApiQuestions() async {
    const url = 'https://the-trivia-api.com/v2/questions?limit=10';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<Map<String, Object>>((json) {
          final List<String> incorrectAnswers = List<String>.from(
            json['incorrectAnswers'],
          );
          final String correctAnswer = json['correctAnswer'];

          List<Map<String, Object>> answers = [
            ...incorrectAnswers.map(
              (text) => {'text': text, 'isCorrect': false},
            ),
            {'text': correctAnswer, 'isCorrect': true},
          ];
          answers.shuffle(); // Shuffle to randomize answer order

          return {
            'questionText': json['question']['text'],
            'answers': answers,
            'explanation': '',
          };
        }).toList();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
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

class User {
  final String id;
  final String name;
  User({required this.id, required this.name});
}

// --- Main Application Widget ---

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserQuizProvider()),
        ChangeNotifierProvider(create: (_) => ApiProvider()),
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

    final ThemeData customTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2ECC71),
        primary: const Color(0xFF2ECC71),
        onPrimary: Colors.white,
        secondary: const Color(0xFF1C1C1C),
        onSecondary: Colors.white,
        tertiary: const Color(0xFFF1C40F),
        onTertiary: Colors.black,
        surface: const Color(0xFFF0F0F0),
        onSurface: const Color(0xFF1C1C1C),
      ),
      fontFamily: 'Montserrat',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Color(0xFF1C1C1C),
        ),
        bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF1C1C1C)),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF2ECC71),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
    );

    return MaterialApp(
      title: 'MindSpark',
      theme: customTheme,
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2ECC71),
          onPrimary: Colors.white,
          secondary: Color(0xFFF1C40F),
          onSecondary: Colors.black,
          tertiary: Color(0xFFF1C40F),
          onTertiary: Colors.black,
          surface: Color(0xFF252525),
          onSurface: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            foregroundColor: Colors.black,
            backgroundColor: const Color(0xFFF1C40F),
          ),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
          shadowColor: Colors.black.withOpacity(0.4),
        ),
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const AuthScreen(),
    );
  }
}

// --- Authentication and State Management ---

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null) {
      Provider.of<UserProvider>(context, listen: false).setCurrentUser(userId);
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  void _login(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    Provider.of<UserProvider>(context, listen: false).setCurrentUser(userId);
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    Provider.of<UserProvider>(context, listen: false).logout();
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return const HomeScreen();
    } else {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_open,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome to MindSpark!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Log in to save your progress and compete on the leaderboard.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => _login('current_user_id'),
                  child: const Text('Log In as Guest'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// --- Home Screen with Navigation ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const WelcomeScreen(),
    const LeaderboardScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.5),
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- Quiz Flow Screens ---

final Map<String, List<Map<String, Object>>> quizData = {
  'Flutter Basics': [
    {
      'questionText': 'What is the main programming language used in Flutter?',
      'answers': [
        {'text': 'Java', 'isCorrect': false},
        {'text': 'Python', 'isCorrect': false},
        {'text': 'Dart', 'isCorrect': true},
        {'text': 'JavaScript', 'isCorrect': false},
      ],
      'explanation':
          'Dart is a client-optimized language for fast apps on any platform.',
    },
    {
      'questionText': 'Which widget is used to display text in Flutter?',
      'answers': [
        {'text': 'Container', 'isCorrect': false},
        {'text': 'Column', 'isCorrect': false},
        {'text': 'Text', 'isCorrect': true},
        {'text': 'Image', 'isCorrect': false},
      ],
      'explanation':
          'The Text widget is used to display a string of text with a single style.',
    },
  ],
  'General Knowledge': [
    {
      'questionText': 'What is the capital of France?',
      'answers': [
        {'text': 'Berlin', 'isCorrect': false},
        {'text': 'Madrid', 'isCorrect': false},
        {'text': 'Paris', 'isCorrect': true},
        {'text': 'Rome', 'isCorrect': false},
      ],
      'explanation': 'Paris is known as the City of Light.',
    },
  ],
};

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userQuizProvider = Provider.of<UserQuizProvider>(context);

    final Map<String, List<Map<String, Object>>> allCategories = {};
    allCategories.addAll(quizData);
    for (var quizMap in userQuizProvider.userQuizzes) {
      allCategories.addAll(quizMap);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Category'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ...allCategories.entries.map((entry) {
            final categoryName = entry.key;
            final questions = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                title: Text(categoryName),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        category: categoryName,
                        questions: questions,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              title: const Text('Random API Quiz'),
              subtitle: const Text('Fetch a new quiz from an external API!'),
              onTap: () async {
                final apiProvider = Provider.of<ApiProvider>(
                  context,
                  listen: false,
                );
                final questions = await apiProvider.fetchApiQuestions();
                if (questions != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        category: 'Random API Quiz',
                        questions: questions,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to fetch API questions. Please try again.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
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
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String category;
  final List<Map<String, Object>> questions;
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
  static const int quizDuration = 100; // 10 minutes in seconds
  int _remainingTime = quizDuration;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _shuffleQuestions();
  }

  void _shuffleQuestions() {
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
    });
    if (isCorrect) {
      _score++;
    }
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
  final Map<String, Object> questionData;
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
    if (oldWidget.questionData['questionText'] !=
        widget.questionData['questionText']) {
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
    final questionText = widget.questionData['questionText'] as String;
    final answers = widget.questionData['answers'] as List<Map<String, Object>>;
    final explanation = widget.questionData['explanation'] as String?;

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
                            : () => widget.answerQuestion(
                                answer['isCorrect'] as bool,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isAnswered
                              ? (answer['isCorrect'] as bool
                                    ? Colors.green.withOpacity(0.7)
                                    : Colors.red.withOpacity(0.7))
                              : Theme.of(context).colorScheme.primary,
                          elevation: 3,
                        ),
                        child: Text(
                          answer['text'] as String,
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

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // In a real app, you would fetch updated leaderboard data from Firebase
            },
          ),
        ],
      ),
      body: userProvider.leaderboardData.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.tertiary,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: userProvider.leaderboardData.length,
                itemBuilder: (context, index) {
                  final entry = userProvider.leaderboardData[index];
                  final isCurrentUser =
                      entry.userId == userProvider.currentUserId;
                  return Card(
                    elevation: isCurrentUser ? 8 : 4,
                    color: isCurrentUser
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : null,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrentUser
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.primary,
                        child: Text(
                          '${index + 1}',
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
                          color: Theme.of(context).colorScheme.primary,
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
            ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'logo',
              child: Icon(
                Icons.emoji_events,
                size: 150,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Test Your Knowledge!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Choose a category and start your quiz quest or create your own!',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Quiz'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MultiplayerScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.group),
              label: const Text('Multiplayer Quiz'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Settings Screen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
            icon: const Icon(Icons.palette),
            label: const Text('Toggle Dark/Light Mode'),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // This is where you would handle the logout logic
              Provider.of<UserProvider>(context, listen: false).logout();
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Log Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class MultiplayerScreen extends StatelessWidget {
  const MultiplayerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer Quiz'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_add,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'This is where real-time multiplayer magic happens!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Impress your audience with this professional feature. You can add logic here to create or join game rooms using Firebase.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
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
        });
      }

      Provider.of<UserQuizProvider>(
        context,
        listen: false,
      ).addQuiz(category, newQuestions);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz created successfully!')),
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
