import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

const String _supabaseUrl = 'https://ayvbtydubxcpevcxcoul.supabase.co';
const String _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF5dmJ0eWR1YnhjcGV2Y3hjb3VsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1NDA2MDQsImV4cCI6MjA4NzExNjYwNH0.iSz583cI1f1Zs9IUJOi3pBHzlIcasYICwmm3aalHdLw';
const String _workerUrl = 'https://fithub-agua-api.mateus2002ns.workers.dev';

const List<String> _hydrationPhrases = [
  "Hora do seu gole de saúde! Que tal um copo de água agora? 💧",
  "Passando para lembrar da sua hidratação. Seu corpo agradece! 💧",
  "Não se esqueça de beber água! Vamos manter o ritmo? 💧",
  "Um gole de água agora vai te dar mais energia. Que tal? 💧",
  "Sua meta está te esperando! Vamos beber mais um copo? 💧",
];

// ─────────────────────────────────────────────
// NOTIFICATION SERVICE
// ─────────────────────────────────────────────
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print("Timezone local inicializado: $timeZoneName");
    } catch (e) {
      print("Erro ao obter timezone local: $e");
    }
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Solicita permissão para Android 13+ e iOS
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      print("Erro ao solicitar permissao de alarme exato: $e");
    }
  }

  static Future<void> scheduleReminder(int intervalMinutes) async {
    await cancelReminder();
    if (intervalMinutes <= 0) return;

    print("Agendando lembretes de hidratação a cada $intervalMinutes minutos.");

    // Agendamos até 5 lembretes sequenciais para garantir que repitam
    for (int i = 1; i <= 5; i++) {
      final scheduleTime = tz.TZDateTime.now(tz.local).add(Duration(minutes: intervalMinutes * i));
      print("Lembrete $i agendado para: $scheduleTime");
      
      await _notificationsPlugin.zonedSchedule(
        id: i, // IDs 1 a 5
        title: 'Hora de beber água! 💧',
        body: _hydrationPhrases[(i - 1) % _hydrationPhrases.length],
        scheduledDate: scheduleTime,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'fithub_agua_reminders_v3',
            'Lembretes de Hidratação',
            channelDescription: 'Notificações periódicas para hidratação ativa',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancelReminder() async {
    for (int i = 1; i <= 5; i++) {
      await _notificationsPlugin.cancel(id: i);
    }
  }

  static Future<void> showImmediateNotification(String title, String body) async {
    await _notificationsPlugin.show(
      id: 0, // ID 0 para notificações imediatas
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fithub_agua_reminders_v2',
          'Lembretes de Hidratação',
          channelDescription: 'Notificações periódicas para hidratação ativa',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  await NotificationService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => HydrationState(),
      child: const FitHubAguaApp(),
    ),
  );
}

// ─────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────
class HydrationState extends ChangeNotifier {
  int currentMl = 0;
  int goalMl = 0;
  int reminderIntervalMinutes = 60; // Padrão de 1 hora
  final List<Map<String, String>> chatHistory = [
    {
      "role": "model",
      "text":
          "Olá! Que bom ter você aqui! Para começar, me conta: qual é o seu peso atual? Assim consigo calcular exatamente quanto você deve tomar de água por dia. 💧"
    }
  ];
  bool isTyping = false;

  void reset() {
    currentMl = 0;
    goalMl = 0;
    reminderIntervalMinutes = 60;
    chatHistory.clear();
    chatHistory.add({
      "role": "model",
      "text":
          "Olá! Que bom ter você aqui! Para começar, me conta: qual é o seu peso atual? Assim consigo calcular exatamente quanto você deve tomar de água por dia. 💧"
    });
    notifyListeners();
  }

  Future<void> _updateLastInteraction() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${userId}_lastInteraction', DateTime.now().toIso8601String());
  }

  Future<void> loadUserData(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Carrega IMEDIATAMENTE os dados locais para resposta instantânea!
    goalMl = prefs.getInt('${userId}_goalMl') ?? 0;
    reminderIntervalMinutes = prefs.getInt('${userId}_reminderInterval') ?? 60;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('${userId}_lastSavedDate') ?? '';
    if (savedDate == todayStr) {
      currentMl = prefs.getInt('${userId}_currentMl') ?? 0;
    } else {
      currentMl = 0;
      await prefs.setInt('${userId}_currentMl', 0);
      await prefs.setString('${userId}_lastSavedDate', todayStr);
    }

    // Carrega o histórico do chat
    final historyJson = prefs.getString('${userId}_chatHistory');
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      chatHistory.clear();
      chatHistory.addAll(decoded.map((item) => {
            "role": item["role"].toString(),
            "text": item["text"].toString(),
          }));
    } else {
      chatHistory.clear();
      chatHistory.add({
        "role": "model",
        "text":
            "Olá! Que bom ter você aqui! Para começar, me conta: qual é o seu peso atual? Assim consigo calcular exatamente quanto você deve tomar de água por dia. 💧"
      });
    }

    // Catch-up de lembretes pendentes caso o app estivesse fechado
    final lastStr = prefs.getString('${userId}_lastInteraction');
    if (lastStr != null) {
      final lastInteraction = DateTime.parse(lastStr);
      final elapsedMinutes = DateTime.now().difference(lastInteraction).inMinutes;
      if (reminderIntervalMinutes > 0 && elapsedMinutes >= reminderIntervalMinutes) {
        final missedCount = (elapsedMinutes ~/ reminderIntervalMinutes).clamp(1, 3);
        for (int i = 0; i < missedCount; i++) {
          chatHistory.add({
            "role": "model",
            "text": _hydrationPhrases[i % _hydrationPhrases.length],
          });
        }
        await prefs.setString('${userId}_chatHistory', jsonEncode(chatHistory));
      }
    }
    await _updateLastInteraction();

    // Atualiza a UI imediatamente com o cache local
    notifyListeners();
    NotificationService.scheduleReminder(reminderIntervalMinutes);

    // 2. Agora, busca atualizações mais recentes do Supabase em segundo plano!
    // Desativado a pedido do usuario para que ao reinstalar o app inicie do zero:
    // _syncWithSupabaseInBackground(userId);
  }

  Future<void> _syncWithSupabaseInBackground(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    bool changed = false;

    // Sincroniza água bebida hoje
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final records = await Supabase.instance.client
          .from('fithub_agua_records')
          .select('amount_ml')
          .eq('user_id', userId)
          .gte('recorded_at', todayStart);

      int totalToday = 0;
      for (var record in records) {
        totalToday += (record['amount_ml'] as num).toInt();
      }
      if (currentMl != totalToday) {
        currentMl = totalToday;
        await prefs.setInt('${userId}_currentMl', currentMl);
        changed = true;
      }
    } catch (e) {
      print("Erro ao sincronizar records do Supabase: $e");
    }

    // Sincroniza o lembrete ativo
    try {
      final reminders = await Supabase.instance.client
          .from('fithub_agua_reminders')
          .select('interval_minutes')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);

      if (reminders.isNotEmpty) {
        final interval = (reminders.first['interval_minutes'] as num).toInt();
        if (reminderIntervalMinutes != interval) {
          reminderIntervalMinutes = interval;
          await prefs.setInt('${userId}_reminderInterval', reminderIntervalMinutes);
          changed = true;
          NotificationService.scheduleReminder(reminderIntervalMinutes);
        }
      }
    } catch (e) {
      print("Erro ao sincronizar lembretes do Supabase: $e");
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _saveUserData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${userId}_currentMl', currentMl);
    await prefs.setInt('${userId}_goalMl', goalMl);
    await prefs.setInt('${userId}_reminderInterval', reminderIntervalMinutes);
    await prefs.setString('${userId}_chatHistory', jsonEncode(chatHistory));

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('${userId}_lastSavedDate', todayStr);
  }

  Future<void> addWater(int amount) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && amount > 0) {
      try {
        await Supabase.instance.client.from('fithub_agua_records').insert({
          'user_id': userId,
          'amount_ml': amount,
        });
      } catch (e) {
        print("Erro ao salvar record no Supabase: $e");
      }
    }

    currentMl = (currentMl + amount).clamp(0, 999999);
    notifyListeners();
    await _saveUserData();
    await _updateLastInteraction();

    // Sempre que beber água, a contagem recomeça!
    NotificationService.scheduleReminder(reminderIntervalMinutes);
  }

  Future<void> setGoal(int amount) async {
    goalMl = amount;
    notifyListeners();
    await _saveUserData();
  }

  Future<void> setReminder(int minutes) async {
    reminderIntervalMinutes = minutes;
    notifyListeners();

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        // Desativa lembretes antigos
        await Supabase.instance.client
            .from('fithub_agua_reminders')
            .update({'is_active': false})
            .eq('user_id', userId);

        // Insere o novo lembrete
        await Supabase.instance.client.from('fithub_agua_reminders').insert({
          'user_id': userId,
          'interval_minutes': minutes,
          'is_active': true,
        });
      } catch (e) {
        print("Erro ao salvar reminder no Supabase: $e");
      }
    }

    await _saveUserData();
    NotificationService.scheduleReminder(minutes);
  }

  Future<void> sendMessage(String text) async {
    chatHistory.add({"role": "user", "text": text});
    isTyping = true;
    notifyListeners();
    await _saveUserData();

    try {
      final geminiHistory =
          chatHistory.sublist(0, chatHistory.length - 1).map((msg) {
        return {
          "role": msg["role"] == "model" ? "model" : "user",
          "parts": [
            {"text": msg["text"]}
          ]
        };
      }).toList();

      final response = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'history': geminiHistory, 'message': text}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['message'] as String? ?? 'Entendido!';
        final payload = data['action_payload'] as Map<String, dynamic>?;

        chatHistory.add({"role": "model", "text": reply});

        if (payload != null) {
          final action = payload['action'] as String?;
          if (action == 'add_water') {
            await addWater((payload['amount_ml'] as num?)?.toInt() ?? 0);
          } else if (action == 'set_goal') {
            await setGoal((payload['amount_ml'] as num?)?.toInt() ?? 2000);
          } else if (action == 'set_reminder') {
            await setReminder((payload['interval_minutes'] as num?)?.toInt() ?? 180);
          }
        }
      } else {
        chatHistory.add({
          "role": "model",
          "text": "Hmm, algo não saiu bem. Pode tentar de novo?"
        });
      }
    } catch (e) {
      chatHistory.add({
        "role": "model",
        "text":
            "Parece que a conexão caiu. Verifique seu Wi-Fi e tente mais uma vez!"
      });
    }

    isTyping = false;
    notifyListeners();
    await _saveUserData();
    await _updateLastInteraction();
  }

  Future<void> sendProgrammedMessage() async {
    isTyping = true;
    notifyListeners();

    final randomPhrase = _hydrationPhrases[DateTime.now().millisecond % _hydrationPhrases.length];

    chatHistory.add({"role": "model", "text": randomPhrase});
    isTyping = false;
    notifyListeners();
    await _saveUserData();
    await _updateLastInteraction();
  }
}

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────
class FitHubAguaApp extends StatelessWidget {
  const FitHubAguaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitHub Água',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme:
            GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
          primary: const Color(0xFF38BDF8),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────
// AUTH GATE
// ─────────────────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        context.read<HydrationState>().reset();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const AuthScreen() : const MainScreen();
  }
}

// ─────────────────────────────────────────────
// AUTH SCREEN (LOGIN + REGISTRO)
// ─────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _animController.reverse().then((_) {
      setState(() => _isLogin = !_isLogin);
      _animController.forward();
    });
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Preencha o e-mail e a senha.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth
            .signInWithPassword(email: email, password: password);
      } else {
        await Supabase.instance.client.auth
            .signUp(email: email, password: password);
        _showInfo(
            'Conta criada! Verifique seu e-mail para confirmar e depois entre.');
      }
    } on AuthException catch (e) {
      _showError(_mapAuthError(e.message));
    } catch (_) {
      _showError('Falha de conexão. Tente novamente.');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _mapAuthError(String msg) {
    if (msg.contains('Invalid login')) return 'E-mail ou senha incorretos.';
    if (msg.contains('Email not confirmed'))
      return 'Confirme seu e-mail antes de entrar.';
    if (msg.contains('User already registered'))
      return 'Este e-mail já tem uma conta. Faça login!';
    if (msg.contains('Password should'))
      return 'A senha precisa ter pelo menos 6 caracteres.';
    return 'Algo deu errado. Tente novamente.';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.teal));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF38BDF8).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2)
                      ],
                    ),
                    child: const Icon(Icons.water_drop,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text('FitHub Água',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin ? 'Bem-vindo de volta!' : 'Crie sua conta grátis',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  // Card
                  GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildField(
                              controller: _email,
                              hint: 'Seu e-mail',
                              icon: Icons.email_outlined),
                          const SizedBox(height: 16),
                          _buildField(
                              controller: _password,
                              hint: 'Senha',
                              icon: Icons.lock_outline,
                              obscure: true),
                          const SizedBox(height: 28),
                          _isLoading
                              ? const CircularProgressIndicator(
                                  color: Color(0xFF38BDF8))
                              : SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        Color(0xFF38BDF8),
                                        Color(0xFF0284C7)
                                      ]),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      onPressed: _submit,
                                      child: Text(
                                        _isLogin ? 'ENTRAR' : 'CRIAR CONTA',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _toggleMode,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 15),
                        children: [
                          TextSpan(
                              text: _isLogin
                                  ? 'Não tem conta? '
                                  : 'Já tem uma conta? '),
                          TextSpan(
                            text: _isLogin ? 'Cadastre-se' : 'Entrar',
                            style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  
  Timer? _reminderTimer;
  int _currentInterval = -1;

  @override
  void initState() {
    super.initState();
    _speech.initialize();
    WidgetsBinding.instance.addObserver(this);
    
    // Cancela os lembretes do sistema operacional imediatamente enquanto o chat está aberto na tela
    NotificationService.cancelReminder();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await context.read<HydrationState>().loadUserData(userId);
        
        // Garante que cancela ao carregar os dados locais também
        NotificationService.cancelReminder();
        
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Ao sair do chat ou fechar, reagenda os lembretes no sistema operacional
    try {
      final interval = context.read<HydrationState>().reminderIntervalMinutes;
      NotificationService.scheduleReminder(interval);
    } catch (_) {}

    _msgController.dispose();
    _scrollController.dispose();
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      final interval = context.read<HydrationState>().reminderIntervalMinutes;
      if (state == AppLifecycleState.resumed) {
        // App aberto em foco na tela: cancela os popups de notificacao para evitar duplicados
        NotificationService.cancelReminder();
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        // App minimizado, fechado ou celular bloqueado: agenda os lembretes exatos no Android
        NotificationService.scheduleReminder(interval);
      }
    } catch (_) {}
  }

  void _setupReminderTimer(int minutes) {
    if (_currentInterval == minutes) return;
    _currentInterval = minutes;
    _reminderTimer?.cancel();
    if (minutes <= 0) return;

    print("Iniciando timer de lembrete em primeiro plano: a cada $minutes minutos.");
    _reminderTimer = Timer.periodic(Duration(minutes: minutes), (timer) async {
      if (!mounted) return;
      final state = context.read<HydrationState>();
      await state.sendProgrammedMessage();
      _scrollToBottom();
    });
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _toggleMic() async {
    if (_isListening) {
      _stopListening();
      return;
    }
    final available = await _speech.initialize(
      onError: (e) {
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _msgController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    if (_isListening) _stopListening();
    context.read<HydrationState>().sendMessage(text);
    _msgController.clear();
    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAddWaterDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1B4B).withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: Row(
              children: [
                const Icon(Icons.water_drop, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Text(
                  'Adicionar Água',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Digite a quantidade consumida:',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Ex: 250 ml',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    suffixText: 'ml',
                    suffixStyle: const TextStyle(color: Color(0xFF38BDF8)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                    ),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'CANCELAR',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final val = int.tryParse(textController.text.trim());
                  if (val != null && val > 0) {
                    context.read<HydrationState>().addWater(val);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text(
                  'ADICIONAR',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HydrationState>();
    final progress =
        state.goalMl > 0 ? (state.currentMl / state.goalMl).clamp(0.0, 1.0) : 0.0;

    _setupReminderTimer(state.reminderIntervalMinutes);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top Bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.water_drop, color: Color(0xFF38BDF8), size: 26),
                          const SizedBox(width: 8),
                          Text(
                            'FitHub Água',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 22),
                        tooltip: 'Sair da conta',
                        onPressed: () async {
                          await Supabase.instance.client.auth.signOut();
                        },
                      ),
                    ],
                  ),
                ),
                // ── Header / Dashboard ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hoje',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: _showAddWaterDialog,
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text('${state.currentMl}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 38,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      Text(
                                          state.goalMl > 0
                                              ? '/ ${state.goalMl} ml'
                                              : ' ml',
                                          style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.6),
                                              fontSize: 16)),
                                    ],
                                  ),
                                ),
                                if (state.goalMl > 0) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.1),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF38BDF8)),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 7,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.1),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF38BDF8)),
                                  strokeCap: StrokeCap.round,
                                ),
                                const Center(
                                    child: Icon(Icons.water_drop,
                                        color: Colors.white, size: 26)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Spacer entre o Header e o Chat
                const SizedBox(height: 20),
                // ── Chat ──
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: state.chatHistory.length + (state.isTyping ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == state.chatHistory.length && state.isTyping) {
                        return const _TypingIndicator();
                      }
                      final msg = state.chatHistory[i];
                      return _ChatBubble(
                        text: msg['text']!,
                        isMe: msg['role'] == 'user',
                      );
                    },
                  ),
                ),
                ),
                // ── Input ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: GlassContainer(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (val) {
                                if (_isListening) {
                                  _stopListening();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: _isListening
                                    ? 'Ouvindo...'
                                    : 'Escreva uma mensagem...',
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.4)),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          // Botão microfone
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: _isListening
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withOpacity(0.15))
                                : null,
                            child: IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening
                                    ? Colors.red
                                    : const Color(0xFF38BDF8),
                              ),
                              onPressed: _toggleMic,
                            ),
                          ),
                          // Botão enviar
                          IconButton(
                            icon: const Icon(Icons.send_rounded,
                                color: Color(0xFF38BDF8)),
                            onPressed: _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  const _ChatBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF0284C7)])
              : null,
          color: isMe ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          border: isMe
              ? null
              : Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(4)),
        ),
        child: const SizedBox(
          width: 40,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Dot(delay: 0),
              _Dot(delay: 150),
              _Dot(delay: 300),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
            color: Color(0xFF38BDF8), shape: BoxShape.circle),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GLASS CONTAINER
// ─────────────────────────────────────────────
class GlassContainer extends StatelessWidget {
  final Widget child;
  const GlassContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
