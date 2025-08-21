// main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:html_unescape/html_unescape.dart';

// ===== DATA MODELS AND PROVIDERS =====
class Question {
  final String questionText;
  final List<Answer> answers;
  final String category;
  final String difficulty;
  final String? explanation;

  Question({
    required this.questionText,
    required this.answers,
    required this.category,
    required this.difficulty,
    this.explanation,
  });

  // Constructor to create a Question from a JSON map
  factory Question.fromJson(Map<String, dynamic> json) {
    final unescape = HtmlUnescape();
    final String decodedQuestion = unescape.convert(json['question']);
    final String decodedCorrectAnswer = unescape.convert(
      json['correct_answer'],
    );
    final List<String> incorrectAnswers = (json['incorrect_answers'] as List)
        .map((answer) => unescape.convert(answer.toString()))
        .toList();

    List<Answer> answersList = [];
    answersList.add(Answer(text: decodedCorrectAnswer, isCorrect: true));
    for (var incorrect in incorrectAnswers) {
      answersList.add(Answer(text: incorrect, isCorrect: false));
    }

    // Shuffle the answers to randomize their order
    answersList.shuffle();

    return Question(
      questionText: decodedQuestion,
      answers: answersList,
      category: json['category'],
      difficulty: json['difficulty'],
      explanation: null, // Open Trivia DB does not provide explanations
    );
  }
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

// Data model for achievements
class Achievement {
  final String id;
  final String title;
  final String description;
  final int targetValue;
  IconData icon;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.icon,
  });
}

class UserProvider with ChangeNotifier {
  String _currentUserId = '';
  String _currentUserName = 'Guest';
  int _score = 0;
  List<LeaderboardEntry> _leaderboardData = [];
  bool _isLoggedIn = false;
  bool _isInitialized = false;
  bool _isTeacher = false;

  // Achievement data
  final List<Achievement> _achievements = [
    Achievement(
      id: 'quiz_whiz',
      title: 'Quiz Whiz',
      description: 'Complete 5 quizzes',
      targetValue: 5,
      icon: Icons.auto_stories,
    ),
    Achievement(
      id: 'perfectionist',
      title: 'Perfectionist',
      description: 'Get a perfect score (10/10)',
      targetValue: 1,
      icon: Icons.star_rate,
    ),
  ];
  Map<String, int> _achievementProgress = {};

  String get currentUserId => _currentUserId;
  String get currentUserName => _currentUserName;
  int get score => _score;
  List<LeaderboardEntry> get leaderboardData {
    _leaderboardData.sort((a, b) => b.score.compareTo(a.score));
    return _leaderboardData;
  }

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  bool get isTeacher => _isTeacher;
  List<Achievement> get achievements => _achievements;
  Map<String, int> get achievementProgress => _achievementProgress;

  Future<void> initUser() async {
    _isInitialized = false;
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _currentUserId = prefs.getString('userId') ?? 'guest_user';
    _currentUserName = prefs.getString('userName') ?? 'Guest';
    _isTeacher = prefs.getBool('isTeacher') ?? false;

    // Load achievement progress from SharedPreferences
    final progressString = prefs.getString('achievementProgress') ?? '{}';
    try {
      _achievementProgress = Map<String, int>.from(jsonDecode(progressString));
    } catch (e) {
      _achievementProgress = {};
    }

    // Ensure all achievements are in the progress map
    for (var achievement in _achievements) {
      _achievementProgress.putIfAbsent(achievement.id, () => 0);
    }

    if (_isLoggedIn) {
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

  Future<void> _saveAchievementProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'achievementProgress',
      jsonEncode(_achievementProgress),
    );
  }

  Future<void> login(String userName, {required bool isTeacher}) async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = true;
    _currentUserId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentUserName = userName;
    _isTeacher = isTeacher;

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', _currentUserId);
    await prefs.setString('userName', _currentUserName);
    await prefs.setBool('isTeacher', _isTeacher);

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
    _isTeacher = false;
    _leaderboardData.removeWhere((entry) => entry.userId == currentUserId);
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('isTeacher');
    notifyListeners();
  }

  void updateScore(int score) {
    _score = score;
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

  // Method to update achievement progress
  void updateAchievementProgress(String achievementId, int value) {
    if (_achievementProgress.containsKey(achievementId)) {
      final currentProgress = _achievementProgress[achievementId]!;
      _achievementProgress[achievementId] = min(
        currentProgress + value,
        _achievements.firstWhere((a) => a.id == achievementId).targetValue,
      );
      _saveAchievementProgress();
      notifyListeners();
    }
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = const Color(0xFF009688);
  Color _tertiaryColor = const Color(0xFFE91E63);

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  Color get tertiaryColor => _tertiaryColor;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }

  void setTertiaryColor(Color color) {
    _tertiaryColor = color;
    notifyListeners();
  }
}

class SoundProvider with ChangeNotifier {
  bool _isSoundEnabled = true;
  final AudioPlayer _player = AudioPlayer();

  bool get isSoundEnabled => _isSoundEnabled;

  SoundProvider() {
    _loadSoundSetting();
  }

  void _loadSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool('isSoundEnabled') ?? true;
    notifyListeners();
  }

  void toggleSound() {
    _isSoundEnabled = !_isSoundEnabled;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isSoundEnabled', _isSoundEnabled);
    });
    notifyListeners();
  }

  void playCorrectSound() async {
    if (_isSoundEnabled) {
      try {
        await _player.setAsset('assets/correct.mp3');
        _player.play();
      } catch (e) {
        // Handle error loading sound
      }
    }
  }

  void playIncorrectSound() async {
    if (_isSoundEnabled) {
      try {
        await _player.setAsset('assets/incorrect.mp3');
        _player.play();
      } catch (e) {
        // Handle error loading sound
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

// ===== QUIZ API SERVICE =====
class QuizApi {
  static const String _baseUrl = 'https://opentdb.com/api.php?';

  static final Map<String, int> _categories = {
    'General Knowledge': 9,
    'Entertainment: Books': 10,
    'Science & Nature': 17,
    'Mythology': 20,
    'History': 23,
    'Politics': 24,
    'Art': 25,
    'Animals': 27,
    'Vehicles': 28,
  };

  static final Map<String, String> _difficulties = {
    'easy': 'easy',
    'medium': 'medium',
    'hard': 'hard',
  };

  static List<String> get availableCategories => _categories.keys.toList();
  static List<String> get availableDifficulties => _difficulties.keys.toList();

  static Future<List<Question>> fetchQuestions({
    required String categoryName,
    required String difficulty,
    int amount = 10,
  }) async {
    final categoryId = _categories[categoryName];
    final difficultyParam = _difficulties[difficulty];

    if (categoryId == null || difficultyParam == null) {
      throw Exception('Invalid category or difficulty selected.');
    }

    final url = Uri.parse(
      '${_baseUrl}amount=$amount&category=$categoryId&difficulty=$difficultyParam&type=multiple',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['response_code'] == 0) {
          final List<dynamic> results = data['results'];
          return results.map((json) => Question.fromJson(json)).toList();
        } else {
          return [];
        }
      } else {
        throw Exception(
          'Failed to load questions from API. Status Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}

// ===== MAIN APP WIDGET =====
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..initUser()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SoundProvider()),
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

    // Define the core color palette.
    final Color primaryColor = themeProvider.primaryColor;
    final Color tertiaryColor = themeProvider.tertiaryColor;
    const Color lightBackground = Color(0xFFF5F5F5);
    const Color darkBackground = Color(0xFF1E1E1E);

    return MaterialApp(
      title: 'Quiz Quest',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          onPrimary: Colors.white,
          secondary: lightBackground,
          tertiary: tertiaryColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: tertiaryColor,
          primary: primaryColor,
          onPrimary: Colors.white,
          secondary: Colors.grey.shade800,
          surface: darkBackground,
          tertiary: tertiaryColor,
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

  final List<Widget> _widgetOptions = <Widget>[
    const WelcomeScreen(),
    const CategoryScreen(),
    const LeaderboardScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToSettings() {
    Navigator.pop(context); // Close the drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _logout() {
    Navigator.pop(context); // Close the drawer
    Provider.of<UserProvider>(context, listen: false).logout();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Quest'),
        centerTitle: false,
        flexibleSpace: Container(
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
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userProvider.currentUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userProvider.isTeacher ? 'Professor' : 'Student',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.quiz),
              title: const Text('Quizzes'),
              selected: _selectedIndex == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard),
              title: const Text('Leaderboard'),
              selected: _selectedIndex == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 2);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: _navigateToSettings,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quizzes'),
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
  String? _selectedRole;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _login() {
    if (_nameController.text.isNotEmpty && _selectedRole != null) {
      bool isTeacher = _selectedRole == 'teacher';
      Provider.of<UserProvider>(
        context,
        listen: false,
      ).login(_nameController.text, isTeacher: isTeacher);
    }
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
              const Text('I am a...', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedRole = 'student';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedRole == 'student'
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      foregroundColor: _selectedRole == 'student'
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.school),
                    label: const Text('Student 🧑‍🎓'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedRole = 'teacher';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedRole == 'teacher'
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      foregroundColor: _selectedRole == 'teacher'
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.class_),
                    label: const Text('Teacher 🧑‍🏫'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _selectedRole != null ? _login : null,
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
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.currentUserName;
    final isTeacher = userProvider.isTeacher;

    // Conditionally set the welcome message based on the user's role
    final welcomeMessage = isTeacher
        ? 'Welcome, Professor $userName!'
        : 'Welcome, $userName!';

    return Scaffold(
      body: Center(
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
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                welcomeMessage,
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
    // Get unique categories from the QuizApi
    final List<String> categories = QuizApi.availableCategories;

    // Get the user provider to check the role
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Quiz Category'),
        flexibleSpace: Container(
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
        ),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories.elementAt(index);
                  return _buildCategoryCard(context, category);
                },
              ),
            ),
            const SizedBox(height: 20),
            // Conditionally show the "Create Quiz" button for teachers
            if (userProvider.isTeacher)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuizCreationScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.create, color: Colors.white),
                label: const Text(
                  'Create Your Own Quiz',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  shadowColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.5),
                  elevation: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String category) {
    final Map<String, IconData> categoryIcons = {
      'General Knowledge': Icons.public,
      'Entertainment: Books': Icons.book,
      'Science & Nature': Icons.rocket_launch,
      'Mythology': Icons.shield_moon,
      'History': Icons.museum,
      'Politics': Icons.gavel,
      'Art': Icons.palette,
      'Animals': Icons.pets,
      'Vehicles': Icons.electric_car,
    };
    final icon = categoryIcons[category] ?? Icons.quiz;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DifficultyScreen(categoryName: category),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              category,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class DifficultyScreen extends StatefulWidget {
  final String categoryName;
  const DifficultyScreen({super.key, required this.categoryName});

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  List<Question>? _questions;
  bool _isLoading = false;
  String? _error;

  Future<void> _fetchQuestions(String difficulty) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final questions = await QuizApi.fetchQuestions(
        categoryName: widget.categoryName,
        difficulty: difficulty,
      );
      if (questions.isNotEmpty) {
        setState(() {
          _questions = questions;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              category: widget.categoryName,
              difficulty: difficulty,
              questions: _questions!,
            ),
          ),
        );
      } else {
        setState(() {
          _error =
              'No questions found for this difficulty. Please try another.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load quiz. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Quiz'),
        flexibleSpace: Container(
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
        ),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : ListView.builder(
                itemCount: QuizApi.availableDifficulties.length,
                itemBuilder: (context, index) {
                  final difficulty = QuizApi.availableDifficulties[index];
                  return Card(
                    elevation: 6,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(difficulty).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        title: Text(
                          difficulty.toUpperCase(),
                          style: TextStyle(
                            color: _getDifficultyColor(difficulty),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: _getDifficultyColor(difficulty),
                        ),
                        onTap: () => _fetchQuestions(difficulty),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String category;
  final String difficulty;
  final List<Question> questions;
  const QuizScreen({
    super.key,
    required this.category,
    required this.difficulty,
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
  bool _showExplanation = false;

  final Map<bool, String> feedbackMessages = {
    true: 'Brilliant!',
    false: 'Don\'t give up! Failure is a stepping stone to success.',
  };

  @override
  void initState() {
    super.initState();
    _startTimer();
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

    // Play sound based on correctness
    if (isCorrect) {
      Provider.of<SoundProvider>(context, listen: false).playCorrectSound();
    } else {
      Provider.of<SoundProvider>(context, listen: false).playIncorrectSound();
    }

    setState(() {
      _isAnswered = true;
      _showExplanation = true;
      if (isCorrect) {
        _score++;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          feedbackMessages[isCorrect]!,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isCorrect ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
      ),
    );

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          if (_questionIndex < widget.questions.length - 1) {
            _questionIndex++;
            _isAnswered = false;
            _showExplanation = false;
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
        title: Text('${widget.category} (${widget.difficulty.toUpperCase()})'),
        flexibleSpace: Container(
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
        ),
        foregroundColor: Colors.white,
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
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LinearProgressIndicator(
                    value: (_questionIndex + 1) / widget.questions.length,
                    backgroundColor: Colors.grey.shade300,
                    color: Theme.of(context).colorScheme.tertiary,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Expanded(
                  child: Quiz(
                    questionData: widget.questions[_questionIndex],
                    answerQuestion: _answerQuestion,
                    isAnswered: _isAnswered,
                  ),
                ),
              ],
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Theme.of(context).colorScheme.secondary,
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
                      child: ElevatedButton.icon(
                        onPressed: widget.isAnswered
                            ? null
                            : () => widget.answerQuestion(answer.isCorrect),
                        icon: widget.isAnswered
                            ? Icon(
                                answer.isCorrect
                                    ? Icons.check_circle
                                    : Icons.close,
                                color: Colors.white,
                              )
                            : const SizedBox.shrink(),
                        label: Text(
                          answer.text,
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isAnswered
                              ? (answer.isCorrect
                                    ? Colors.green.shade600
                                    : Colors.red.shade600)
                              : Theme.of(context).colorScheme.primary,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  color: Theme.of(context).colorScheme.secondary,
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

  // Method to check and update achievement progress
  void _updateAchievements(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Increment 'Quiz Whiz' progress by 1
    userProvider.updateAchievementProgress('quiz_whiz', 1);

    // If a perfect score is achieved, update 'Perfectionist' progress to 1
    if (score == totalQuestions) {
      userProvider.updateAchievementProgress('perfectionist', 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateAchievements(context); // Call the achievement update logic
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
  final List<Color> _primaryColorOptions = [
    const Color(0xFF009688), // Teal
    Colors.deepPurple,
    Colors.blue,
    Colors.red,
    Colors.green,
  ];

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
    final soundProvider = Provider.of<SoundProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        flexibleSpace: Container(
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
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
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
            const SizedBox(height: 32),
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Toggle Dark/Light Mode'),
              trailing: Switch(
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Primary Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _primaryColorOptions.map((color) {
                return GestureDetector(
                  onTap: () {
                    themeProvider.setPrimaryColor(color);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeProvider.primaryColor == color
                            ? Colors.blue
                            : Colors.transparent,
                        width: 3.0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Text('Sound', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Sound Effects'),
              trailing: Switch(
                value: soundProvider.isSoundEnabled,
                onChanged: (value) {
                  soundProvider.toggleSound();
                },
              ),
            ),
          ],
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
    final achievements = userProvider.achievements;
    final achievementProgress = userProvider.achievementProgress;
    final currentUserId = userProvider.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        flexibleSpace: Container(
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
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Your Achievements Card
            const Text(
              'Your Achievements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...achievements.map((achievement) {
              final progress = achievementProgress[achievement.id] ?? 0;
              final target = achievement.targetValue;
              final isCompleted = progress >= target;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: Icon(
                    achievement.icon,
                    size: 40,
                    color: isCompleted
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    achievement.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isCompleted ? 'Completed!' : achievement.description,
                  ),
                  trailing: isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : Text('$progress / $target'),
                ),
              );
            }).toList(),

            const SizedBox(height: 20),

            // Leaderboard List
            const Text(
              'Top Scores',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (leaderboardData.isEmpty)
              const Center(child: Text('No scores to display yet.'))
            else
              ...leaderboardData.map((entry) {
                final rank = leaderboardData.indexOf(entry) + 1;
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
              }).toList(),
          ],
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
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final List<TextEditingController> _answerControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  List<bool> _isCorrect = List.generate(4, (index) => false);
  String? _selectedDifficulty = 'easy';
  bool _isLoading = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _questionController.dispose();
    _explanationController.dispose();
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generateQuestionWithAI() async {
    if (_categoryController.text.isEmpty || _selectedDifficulty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a category and select a difficulty.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _questionController.clear();
      _explanationController.clear();
      for (var controller in _answerControllers) {
        controller.clear();
      }
      _isCorrect = List.generate(4, (index) => false);
    });

    try {
      final prompt =
          """
      Generate a single new multiple-choice quiz question with the following properties:
      - Category: "${_categoryController.text}"
      - Difficulty: "${_selectedDifficulty}"
      - Must have exactly one correct answer.
      - Must have exactly 4 possible answers.
      - Must include a brief explanation.
      
      Provide the response as a JSON object with the following schema:
      {
        "questionText": "string",
        "answers": [
          {"text": "string", "isCorrect": boolean},
          {"text": "string", "isCorrect": boolean},
          {"text": "string", "isCorrect": boolean},
          {"text": "string", "isCorrect": boolean}
        ],
        "explanation": "string"
      }
      """;

      const apiKey = '';
      const apiUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key=$apiKey';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final generatedText =
            jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        final questionData = jsonDecode(generatedText);

        setState(() {
          _questionController.text = questionData['questionText'];
          _explanationController.text = questionData['explanation'];

          for (int i = 0; i < 4; i++) {
            _answerControllers[i].text = questionData['answers'][i]['text'];
            _isCorrect[i] = questionData['answers'][i]['isCorrect'];
          }
        });
      } else {
        throw Exception('Failed to generate question: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating question: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _submitQuiz() {
    if (_formKey.currentState!.validate()) {
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
        flexibleSpace: Container(
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
        ),
        foregroundColor: Colors.white,
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
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateQuestionWithAI,
                icon: _isLoading
                    ? const CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        backgroundColor: Colors.white,
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isLoading ? 'Generating...' : 'Generate with AI',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  shadowColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.5),
                  elevation: 8,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _questionController,
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
                minLines: 1,
                maxLines: 5,
              ),
              const SizedBox(height: 20),
              ..._answerControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Answer ${index + 1}',
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
                      const SizedBox(width: 8),
                      Checkbox(
                        value: _isCorrect[index],
                        onChanged: (bool? value) {
                          if (value == true) {
                            setState(() {
                              for (int i = 0; i < _isCorrect.length; i++) {
                                _isCorrect[i] = (i == index);
                              }
                            });
                          }
                        },
                      ),
                      const Text('Correct'),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _explanationController,
                decoration: InputDecoration(
                  labelText: 'Explanation (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                minLines: 1,
                maxLines: 5,
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
