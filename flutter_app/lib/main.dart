import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/todo.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/local_timer_store.dart';
import 'screens/login_screen.dart';
import 'screens/todo_list_screen.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService('http://127.0.0.1:5000');
  final auth = AuthService(api);
  await auth.loadSavedToken();
  runApp(MyApp(api: api, auth: auth));
}

class MyApp extends StatelessWidget {
  final ApiService? api;
  final AuthService? auth;
  const MyApp({this.api, this.auth, super.key});

  @override
  Widget build(BuildContext context) {
    final ApiService apiClient = api ?? ApiService('http://127.0.0.1:5000');
    final AuthService authService = auth ?? AuthService(apiClient);
    return MaterialApp(
      title: 'Todo Flutter',
      theme: ThemeData.dark().copyWith(
        primaryColor: AppColors.brightYellow,
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: AppColors.lightGray),
      ),
      initialRoute: '/todos',
      routes: {
        '/': (c) => HomeScreen(api: apiClient, auth: authService),
        '/login': (c) => LoginScreen(api: apiClient, auth: authService),
        '/todos': (c) => TodoListScreen(api: apiClient, auth: authService),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ApiService api;
  final AuthService auth;
  const HomeScreen({required this.api, required this.auth, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocalTimerStore _store = LocalTimerStore();
  List<Todo> todos = [];

  @override
  void initState() {
    super.initState();
    // Load persisted task timer states (keeps _store referenced so analyzer won't warn).
    _store.loadAll().then(
      (m) => debugPrint('Loaded \\${m.length} timer states'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do App (Flutter)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: () async {
              // Sign-in flow to be implemented: Google Sign-In + backend exchange.
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign-in'),
                  content: const Text(
                    'Sign-in flow not implemented in scaffold yet.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Flutter skeleton created — next: implement UI & logic'),
      ),
    );
  }
}
