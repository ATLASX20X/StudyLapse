import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'screens/explorer_screen.dart';
import 'screens/home_feed_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/timelapse_preview_screen.dart';
import 'screens/user_profile_screen.dart';
import 'services/supabase_service.dart';
import 'services/timelapse_capture_service.dart';
import 'services/timelapse_video_service.dart' as video_service;
import 'services/friend_service.dart';
import 'widgets/timelapse_camera_preview.dart';

typedef TimelapseOrientation = video_service.TimelapseOrientation;

// Flag global pour savoir si Supabase est disponible
bool isSupabaseAvailable = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Supabase en mode "graceful degradation"
  // Si Supabase échoue, l'app continue quand même
  try {
    await SupabaseService.instance.initialize();
    isSupabaseAvailable = true;
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    isSupabaseAvailable = false;
    debugPrint('⚠️ Supabase initialization failed: $e');
    debugPrint('App will continue in local mode');
  }

  runApp(const StudyLapseApp());
}

// ============================================================
// CONFIGURATION GENERALE
// ============================================================

const Color backgroundColor = Color(0xFF101116);
const Color surfaceColor = Color(0xFF1B1C25);
const Color accentColor = Color(0xFF9B8AFF);
const Color secondaryColor = Color(0xFF67DCC0);

class StudyLapseApp extends StatefulWidget {
  const StudyLapseApp({super.key});

  @override
  State<StudyLapseApp> createState() => _StudyLapseAppState();
}

class _StudyLapseAppState extends State<StudyLapseApp> {
  final List<StudySession> _sessions = [];
  bool _isAuthenticated = false;
  bool _isLoadingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    if (!isSupabaseAvailable) {
      setState(() {
        _isLoadingAuth = false;
        _isAuthenticated = false;
      });
      return;
    }

    // Vérifier l'état d'authentification initial
    final session = SupabaseService.instance.client.auth.currentSession;
    _isAuthenticated = session != null;
    _isLoadingAuth = false;

    // Écouter les changements d'authentification
    SupabaseService.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _isAuthenticated = data.session != null;
        });
      }
    });

    setState(() {});
  }

  void _addSession(StudySession session) {
    setState(() {
      _sessions.add(session);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyLapse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: surfaceColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: _isLoadingAuth
          ? const _LoadingScreen()
          : _isAuthenticated
              ? StudyLapseHome(sessions: _sessions, onSessionFinished: _addSession)
              : const LoginScreen(),
    );
  }
}

// ============================================================
// LOADING SCREEN
// ============================================================

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: accentColor),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MODELE DE DONNEES
// ============================================================

class Subject {
  const Subject({required this.name, required this.emoji});

  final String name;
  final String emoji;

  static const List<Subject> predefinedSubjects = [
    Subject(name: 'Mathématiques', emoji: '📐'),
    Subject(name: 'Physique', emoji: '⚛️'),
    Subject(name: 'Chimie', emoji: '🧪'),
    Subject(name: 'Biologie', emoji: '🧬'),
    Subject(name: 'Histoire', emoji: '📜'),
    Subject(name: 'Géographie', emoji: '🌍'),
    Subject(name: 'Français', emoji: '📖'),
    Subject(name: 'Anglais', emoji: '🇬🇧'),
    Subject(name: 'Espagnol', emoji: '🇪🇸'),
    Subject(name: 'Allemand', emoji: '🇩🇪'),
    Subject(name: 'Philosophie', emoji: '🤔'),
    Subject(name: 'Économie', emoji: '📊'),
    Subject(name: 'Informatique', emoji: '💻'),
    Subject(name: 'Droit', emoji: '⚖️'),
    Subject(name: 'Médecine', emoji: '🏥'),
    Subject(name: 'Art', emoji: '🎨'),
    Subject(name: 'Musique', emoji: '🎵'),
    Subject(name: 'Sport', emoji: '⚽'),
    Subject(name: 'Autre', emoji: '📚'),
  ];

  static List<Subject> searchSubjects(String query) {
    if (query.isEmpty) return predefinedSubjects;
    final lowerQuery = query.toLowerCase();
    return predefinedSubjects
        .where((subject) => subject.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}

class StudySession {
  const StudySession({
    required this.durationSeconds,
    required this.finishedAt,
    this.imagePaths = const [],
    this.captureDirectoryPath,
    this.description = '',
    this.visibility = SessionVisibility.public,
  });

  final int durationSeconds;
  final DateTime finishedAt;

  final List<String> imagePaths;
  final String? captureDirectoryPath;
  final String description;
  final SessionVisibility visibility;
}

enum SessionVisibility {
  public,
  friends,
  private,
}

// ============================================================
// NAVIGATION PRINCIPALE
// ============================================================

class StudyLapseHome extends StatefulWidget {
  const StudyLapseHome({
    super.key,
    required this.sessions,
    required this.onSessionFinished,
  });

  final List<StudySession> sessions;
  final ValueChanged<StudySession> onSessionFinished;

  @override
  State<StudyLapseHome> createState() => _StudyLapseHomeState();
}

class _StudyLapseHomeState extends State<StudyLapseHome> {
  int _selectedIndex = 0;
  bool _isRecordingFullscreen = false;

  void _setRecordingFullscreen(bool value) {
    setState(() {
      _isRecordingFullscreen = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeFeedScreen(),
      const ExplorerScreen(),
      SessionScreen(
        onFinished: widget.onSessionFinished,
        isActive: _selectedIndex == 2,
        onFullscreenChanged: _setRecordingFullscreen,
      ),
      StatsScreen(sessions: widget.sessions),
      const UserProfileScreen(),
    ];

    const titles = [
      'Feed',
      'Explorer',
      'Session de travail',
      'Statistiques',
      'Profil',
    ];

    return Scaffold(
      appBar: _isRecordingFullscreen
          ? null
          : AppBar(
              title: Text(
                titles[_selectedIndex],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: accentColor,
                    size: 27,
                  ),
                ),
              ],
            ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _isRecordingFullscreen
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              backgroundColor: surfaceColor,
              indicatorColor: accentColor.withValues(alpha: 0.20),
              destinations: const [
                NavigationDestination(
                  key: ValueKey('nav_home'),
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Feed',
                ),
                NavigationDestination(
                  key: ValueKey('nav_explorer'),
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: 'Explorer',
                ),
                NavigationDestination(
                  key: ValueKey('nav_session'),
                  icon: Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer_rounded),
                  label: 'Session',
                ),
                NavigationDestination(
                  key: ValueKey('nav_stats'),
                  icon: Icon(Icons.bar_chart_rounded),
                  label: 'Stats',
                ),
                NavigationDestination(
                  key: ValueKey('nav_profile'),
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
              ],
            ),
    );
  }
}

// ============================================================
// ECRAN ACCUEIL
// ============================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.sessions});

  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = sessions.fold<int>(
      0,
      (total, session) => total + session.durationSeconds,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Construis ta progression.',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Chaque session compte. Continue sur ta lancée.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        ),
        const SizedBox(height: 24),

        // Carte de progression
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF37305D), Color(0xFF242139)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt_rounded, color: accentColor, size: 30),
              const SizedBox(height: 14),
              const Text(
                'Ton travail, tes progrès.',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${sessions.length} session(s) terminée(s)',
                style: TextStyle(color: Colors.grey.shade300),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    '${totalSeconds ~/ 60} minutes de travail',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),
        const SectionTitle(title: 'Ton espace de travail'),
        const SizedBox(height: 12),

        const FeatureCard(
          icon: Icons.camera_alt_outlined,
          title: 'Study timelapse',
          description: 'Enregistre tes sessions et visualise le temps que tu consacres à tes études.',
          color: accentColor,
          tag: 'À venir',
        ),
        const SizedBox(height: 12),
        const FeatureCard(
          icon: Icons.people_outline_rounded,
          title: 'Étudier ensemble',
          description: 'Découvre les sessions et les progrès de la communauté StudyLapse.',
          color: secondaryColor,
          tag: 'À venir',
        ),

        const SizedBox(height: 28),
        const SectionTitle(title: 'Dernières sessions'),
        const SizedBox(height: 12),

        if (sessions.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_rounded,
            title: 'Tout commence ici',
            message: 'Lance ta première session de travail pour voir apparaître tes progrès.',
          )
        else
          ...sessions.reversed
              .take(3)
              .map((session) => SessionHistoryTile(session: session)),
      ],
    );
  }
}

// ============================================================
// ECRAN SESSION
// ============================================================

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.onFinished,
    this.isActive = false,
    this.onFullscreenChanged,
  });

  final ValueChanged<StudySession> onFinished;
  final bool isActive;
  final ValueChanged<bool>? onFullscreenChanged;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  bool _hasStarted = false;
  Timer? _timer;
  bool _isPowerSavingMode = false;
  CameraLensDirection _selectedCameraDirection = CameraLensDirection.back;

  @override
  void dispose() {
    _timer?.cancel();
    // Disable wakelock when screen is disposed
    WakelockPlus.disable();
    super.dispose();
  }

  void _start() {
    setState(() {
      _isRunning = true;
      _hasStarted = true;
    });
    // Enable wakelock to prevent screen from sleeping
    WakelockPlus.enable();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    // Disable wakelock when paused
    WakelockPlus.disable();
  }

  void _handleCaptureResult(TimelapseCaptureResult? result) async {
    final duration = _elapsedSeconds;

    _timer?.cancel();
    _timer = null;

    setState(() {
      _elapsedSeconds = 0;
      _isRunning = false;
      _hasStarted = false;
      _isPowerSavingMode = false;
    });

    if (result == null) {
      debugPrint('No capture result');
      return;
    }

    widget.onFinished(
      StudySession(
        durationSeconds: duration,
        finishedAt: DateTime.now(),
        imagePaths: result.imagePaths,
        captureDirectoryPath: result.directoryPath,
        description: '',
        visibility: SessionVisibility.public,
      ),
    );

    if (result.imageCount > 0 && mounted) {
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => TimelapsePreviewScreen(
                captureResult: result,
                durationSeconds: duration,
                orientation: TimelapseOrientation.portrait,
              ),
            ),
          )
          .whenComplete(() {
            SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          });
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guide rapide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⏱️ Personnalisation'),
              SizedBox(height: 8),
              Text('Après l\'enregistrement, tu peux choisir la durée de la vidéo (5 à 30 secondes), le filigrane et la rotation.'),
              SizedBox(height: 16),
              Text('🎨 Filigranes'),
              SizedBox(height: 8),
              Text('6 styles disponibles : Aucun, Empilé, Cercle, Horloge, Chronomètre, Barre de chargement. Choisis celui que tu préfères !'),
              SizedBox(height: 16),
              Text('🌍 Publication'),
              SizedBox(height: 8),
              Text('Tu peux publier ton timelapse à tout le monde, seulement à tes amis, ou le garder privé. Ajoute une description pour personnaliser ton post.'),
              SizedBox(height: 16),
              Text('📱 Export'),
              SizedBox(height: 8),
              Text('Sauvegarde dans ta galerie ou partage sur Instagram, TikTok, WhatsApp depuis ton appareil.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris !'),
          ),
        ],
      ),
    );
  }

  void _togglePowerSavingMode() {
    setState(() {
      _isPowerSavingMode = !_isPowerSavingMode;
      // Also toggle fullscreen when power saving mode changes
      widget.onFullscreenChanged?.call(_isPowerSavingMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = TimelapseCameraPreview(
      isActive: widget.isActive,
      elapsedSeconds: _elapsedSeconds,
      hasStarted: _hasStarted,
      isRunning: _isRunning,
      onStart: _start,
      onTogglePause: _pause,
      onStop: _handleCaptureResult,
      initialCameraDirection: _selectedCameraDirection,
      onCameraDirectionChanged: (direction) {
        setState(() {
          _selectedCameraDirection = direction;
        });
      },
      onShowInfo: _hasStarted ? null : _showInfoDialog,
      isPowerSavingMode: _isPowerSavingMode,
      onTogglePowerSaving: _togglePowerSavingMode,
    );

    if (_hasStarted) {
      // Full screen when recording started
      return Stack(
        children: [
          preview,
          // Full screen black overlay in power saving mode
          if (_isPowerSavingMode)
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePowerSavingMode,
                child: Container(color: Colors.black),
              ),
            ),
        ],
      );
    }

    return SafeArea(
      child: Padding(padding: const EdgeInsets.all(12), child: preview),
    );
  }
}

// ============================================================
// ECRAN STATISTIQUES
// ============================================================

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.sessions});

  final List<StudySession> sessions;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    if (!isSupabaseAvailable) return;
    
    try {
      final friendService = FriendService();
      final requests = await friendService.getPendingRequests();
      if (mounted) {
        setState(() {
          _pendingRequestsCount = requests.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.sessions.fold<int>(
      0,
      (total, session) => total + session.durationSeconds,
    );

    final today = DateTime.now();
    final todaySessions = widget.sessions.where((session) {
      final date = session.finishedAt;
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: backgroundColor,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  ).then((_) => _loadPendingRequests());
                },
              ),
              if (_pendingRequestsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _pendingRequestsCount > 9 ? '9+' : '$_pendingRequestsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tes statistiques',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Observe le travail que tu accomplis.',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'Sessions',
                value: '${widget.sessions.length}',
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.today_rounded,
                title: "Aujourd'hui",
                value: '$todaySessions',
                color: secondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StatCard(
          icon: Icons.schedule_rounded,
          title: 'Temps total de travail',
          value: formatLongDuration(totalSeconds),
          color: const Color(0xFFFFC777),
        ),

        const SizedBox(height: 30),
        const SectionTitle(title: 'Historique'),
        const SizedBox(height: 12),

        if (widget.sessions.isEmpty)
          const EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'Pas encore de statistiques',
            message: 'Tes données apparaîtront ici dès que tu auras terminé une session.',
          )
        else
          ...widget.sessions.reversed.map(
            (session) => SessionHistoryTile(session: session),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ECRAN PROFIL
// ============================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Étudiant StudyLapse';

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le profil'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Ton nom',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            controller.dispose();
            Navigator.pop(dialogContext, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _name = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 52,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Chaque jour est une nouvelle occasion de progresser.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 32),

        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_outlined, color: accentColor),
            title: const Text('Modifier mon nom'),
            subtitle: const Text('Personnalise ton profil local'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _editName,
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: secondaryColor),
              title: Text('Timelapse'),
              subtitle: Text('Fonctionnalité disponible'),
            ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_outlined, color: accentColor),
              title: Text('Compte et synchronisation'),
              subtitle: Text('Bientôt disponible'),
            ),
        ),
        const SizedBox(height: 30),
        Center(
          child: Text(
            'STUDYLAPSE • PREMIER PROTOTYPE',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// COMPOSANTS REUTILISABLES
// ============================================================

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.white24),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.tag,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tag != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tag!,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SessionHistoryTile extends StatelessWidget {
  const SessionHistoryTile({super.key, required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: surfaceColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.play_arrow_rounded, color: accentColor),
        ),
        title: Text(
          formatDuration(session.durationSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          formatDateTime(session.finishedAt),
          style: TextStyle(color: Colors.white70),
        ),
        trailing: Text(
          '${session.imagePaths.length} photos',
          style: TextStyle(
            color: secondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
  if (minutes > 0) {
    return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
  }
  return '$seconds s';
}

String formatLongDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
  if (minutes > 0) {
    return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
  }
  return '$seconds s';
}

String formatDateTime(DateTime dateTime) {
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}
