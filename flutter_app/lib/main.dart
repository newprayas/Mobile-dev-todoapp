import 'package:flutter/material.dart';
import 'dart:io'
    show Platform, HttpClient; // Added HttpClient for backend readiness check
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/todo.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/local_timer_store.dart';
import 'screens/login_screen.dart';
import 'screens/todo_list_screen.dart';
import 'theme/app_colors.dart';
import 'services/notification_service.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.init();
  // Allow overriding the API host at build/run time with --dart-define=API_BASE_URL
  const envBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  String chooseBaseUrl() {
    if (envBase.isNotEmpty) return envBase;
    // Android emulator -> host machine is reachable at 10.0.2.2
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    // iOS simulator and other platforms can use localhost
    return 'http://127.0.0.1:5000';
  }

  final baseUrl = chooseBaseUrl();
  // show chosen base for easier debugging during development
  if (kDebugMode) debugPrint('Using API baseUrl: $baseUrl');
  // Dev-only: wait briefly for backend readiness (helps avoid connection refused race)
  await _waitForBackend(baseUrl, attempts: 8, delayMs: 400);
  final api = ApiService(baseUrl);
  final auth = AuthService(api);
  await auth.loadSavedToken();
  runApp(MyApp(api: api, auth: auth, notificationService: notificationService));
}

// Simple readiness / liveness wait loop for local backend. Will not throw;
// it only logs status to avoid blocking app start indefinitely.
Future<void> _waitForBackend(
  String baseUrl, {
  int attempts = 5,
  int delayMs = 500,
}) async {
  final lower = baseUrl.toLowerCase();
  final isLocal =
      lower.contains('127.0.0.1') ||
      lower.contains('localhost') ||
      lower.contains('10.0.2.2');
  if (!isLocal) return; // Only applicable for local dev
  if (kDebugMode)
    debugPrint('BACKEND WAIT: Checking backend readiness at $baseUrl');
  final uri = Uri.parse(baseUrl + '/health');
  for (var i = 1; i <= attempts; i++) {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        if (kDebugMode)
          debugPrint('BACKEND WAIT: Backend healthy (attempt $i/$attempts).');
        client.close(force: true);
        return;
      } else {
        if (kDebugMode)
          debugPrint(
            'BACKEND WAIT: Unexpected status ${resp.statusCode} (attempt $i/$attempts)',
          );
      }
      client.close(force: true);
    } catch (e) {
      if (kDebugMode)
        debugPrint('BACKEND WAIT: attempt $i/$attempts failed: $e');
    }
    await Future.delayed(Duration(milliseconds: delayMs));
  }
  if (kDebugMode)
    debugPrint(
      'BACKEND WAIT: Proceeding without positive health confirmation.',
    );
}

class MyApp extends StatelessWidget {
  final ApiService? api;
  final AuthService? auth;
  final NotificationService? notificationService;
  const MyApp({this.api, this.auth, this.notificationService, super.key});

  @override
  Widget build(BuildContext context) {
    final ApiService apiClient = api ?? ApiService('http://127.0.0.1:5000');
    final AuthService authService = auth ?? AuthService(apiClient);
    final NotificationService notificationManager =
        notificationService ?? NotificationService();
    return MaterialApp(
      title: 'Todo Flutter',
      theme: ThemeData.dark().copyWith(
        primaryColor: AppColors.brightYellow,
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: AppColors.lightGray),
      ),
      home: AuthWrapper(
        api: apiClient,
        auth: authService,
        notificationService: notificationManager,
      ),
      routes: {
        '/login': (c) => LoginScreen(api: apiClient, auth: authService),
        '/todos': (c) => TodoListScreen(
          api: apiClient,
          auth: authService,
          notificationService: notificationManager,
        ),
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
      (m) => debugPrint('Loaded \${m.length} timer states'),
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
