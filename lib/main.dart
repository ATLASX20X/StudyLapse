import 'dart:async';

import 'package:flutter/material.dart';

void main() {
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
      home: StudyLapseHome(sessions: _sessions, onSessionFinished: _addSession),
    );
  }
}

// ============================================================
// MODELE DE DONNEES
// ============================================================

class StudySession {
  const StudySession({required this.durationSeconds, required this.finishedAt});

  final int durationSeconds;
  final DateTime finishedAt;
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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(sessions: widget.sessions),
      SessionScreen(onFinished: widget.onSessionFinished),
      StatsScreen(sessions: widget.sessions),
      const ProfileScreen(),
    ];

    const titles = [
      'StudyLapse',
      'Session de travail',
      'Statistiques',
      'Profil',
    ];

    return Scaffold(
      appBar: AppBar(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: surfaceColor,
        indicatorColor: accentColor.withValues(alpha: 0.20),
        destinations: const [
          NavigationDestination(
            key: ValueKey('nav_home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
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
// ECRAN SESSION : CHRONOMETRE FONCTIONNEL
// ============================================================

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.onFinished});

  final ValueChanged<StudySession> onFinished;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;

  void _start() {
    if (_isRunning) return;

    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isRunning = false);
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;

    if (_elapsedSeconds > 0) {
      widget.onFinished(
        StudySession(
          durationSeconds: _elapsedSeconds,
          finishedAt: DateTime.now(),
        ),
      );
    }

    setState(() {
      _elapsedSeconds = 0;
      _isRunning = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Session terminée.')));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Concentre-toi sur l’essentiel.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Le temps que tu investis aujourd’hui construit tes progrès.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 42),

        // Cadran du chronomètre
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceColor,
              border: Border.all(
                color: _isRunning ? secondaryColor : accentColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isRunning ? secondaryColor : accentColor).withValues(
                    alpha: 0.12,
                  ),
                  blurRadius: 35,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isRunning ? Icons.bolt_rounded : Icons.hourglass_empty,
                  color: _isRunning ? secondaryColor : accentColor,
                  size: 36,
                ),
                const SizedBox(height: 16),
                Text(
                  formatDuration(_elapsedSeconds),
                  key: const ValueKey('session_timer'),
                  style: const TextStyle(
                    fontSize: 39,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRunning ? 'CONCENTRATION EN COURS' : 'PRÊT À COMMENCER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 36),

        // Commandes
        FilledButton.icon(
          onPressed: _isRunning ? _pause : _start,
          icon: Icon(
            _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
          label: Text(_isRunning ? 'Mettre en pause' : 'Démarrer'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: accentColor,
            foregroundColor: backgroundColor,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _elapsedSeconds == 0 ? null : _finish,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Terminer la session'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),

        const SizedBox(height: 28),
        const FeatureCard(
          icon: Icons.videocam_outlined,
          title: 'Enregistrement timelapse',
          description: 'La capture vidéo automatique sera ajoutée dans une prochaine étape.',
          color: secondaryColor,
          tag: 'À venir',
        ),
      ],
    );
  }
}

// ============================================================
// ECRAN STATISTIQUES
// ============================================================

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.sessions});

  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = sessions.fold<int>(
      0,
      (total, session) => total + session.durationSeconds,
    );

    final today = DateTime.now();
    final todaySessions = sessions.where((session) {
      final date = session.finishedAt;
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;

    return ListView(
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
                value: '${sessions.length}',
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.today_rounded,
                title: 'Aujourd’hui',
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

        if (sessions.isEmpty)
          const EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'Pas encore de statistiques',
            message: 'Tes données apparaîtront ici dès que tu auras terminé une session.',
          )
        else
          ...sessions.reversed.map(
            (session) => SessionHistoryTile(session: session),
          ),
      ],
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
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    controller.dispose();

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
            subtitle: Text('Fonctionnalité en développement'),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_outlined, color: accentColor),
            title: Text('Compte et synchronisation'),
            subtitle: Text('La connexion et Supabase seront ajoutés ensuite'),
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

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.tag,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade400, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tag.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 27),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionHistoryTile extends StatelessWidget {
  const SessionHistoryTile({super.key, required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context) {
    final date = session.finishedAt;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} à '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x332FAF91),
          child: Icon(Icons.check_rounded, color: secondaryColor),
        ),
        title: Text(formatLongDuration(session.durationSeconds)),
        subtitle: Text(dateLabel),
        trailing: const Icon(Icons.chevron_right_rounded),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 38, color: accentColor),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FORMATAGE DU TEMPS
// ============================================================

String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String formatLongDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours} h ${minutes.toString().padLeft(2, '0')} min';
  }
  if (minutes > 0) {
    return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
  }
  return '$seconds s';
}
