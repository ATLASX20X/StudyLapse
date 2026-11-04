import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/post.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';

class TimelapseExportScreen extends StatefulWidget {
  const TimelapseExportScreen({
    super.key,
    required this.videoPath,
    required this.durationSeconds,
    this.subject,
  });

  final String videoPath;
  final int durationSeconds;
  final String? subject;

  @override
  State<TimelapseExportScreen> createState() => _TimelapseExportScreenState();
}

class _TimelapseExportScreenState extends State<TimelapseExportScreen> {
  late VideoPlayerController _player;
  bool _isInitialized = false;
  bool _isSavingToGallery = false;
  bool _savedToGallery = false;
  bool _isPublishing = false;
  bool _publishedInApp = false;

  final TextEditingController _descriptionController = TextEditingController();
  SessionVisibility _visibility = SessionVisibility.public;
  
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final PostService _postService = PostService();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _player = VideoPlayerController.file(File(widget.videoPath));
    await _player.initialize();
    await _player.setLooping(true);
    await _player.play();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveToGallery() async {
    if (_isSavingToGallery || _savedToGallery) return;

    setState(() {
      _isSavingToGallery = true;
    });

    try {
      await Gal.putVideo(File(widget.videoPath).path, album: 'StudyLapse');

      if (mounted) {
        setState(() {
          _savedToGallery = true;
          _isSavingToGallery = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vidéo sauvegardée dans la galerie !'),
            backgroundColor: secondaryColor,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSavingToGallery = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde : $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareToSocialMedia() async {
    // Pour l'instant, on utilise la galerie comme fallback
    // L'intégration avec les réseaux sociaux nécessitera des packages supplémentaires
    // comme share_plus ou esys_flutter_share
    await _saveToGallery();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vidéo sauvegardée ! Partage-la depuis ta galerie.'),
          backgroundColor: accentColor,
        ),
      );
    }
  }

  Future<void> _publishInApp() async {
    setState(() {
      _isPublishing = true;
    });

    try {
      // Check if user is authenticated
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('Vous devez être connecté pour publier');
      }

      // Upload video to Supabase Storage
      final videoFile = File(widget.videoPath);
      final postId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final videoUrl = await _storageService.uploadVideo(
        videoFile: videoFile,
        userId: currentUser.id,
        postId: postId,
      );

      // Create post in database
      await _postService.createPost(
        authorId: currentUser.id,
        authorUsername: currentUser.username,
        videoUrl: videoUrl,
        description: _descriptionController.text.trim(),
        subject: widget.subject?.trim(),
        durationSeconds: widget.durationSeconds,
        visibility: _convertVisibility(_visibility),
      );

      setState(() {
        _publishedInApp = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publié dans ton feed StudyLapse !'),
            backgroundColor: secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de publication: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  PostVisibility _convertVisibility(SessionVisibility visibility) {
    switch (visibility) {
      case SessionVisibility.public:
        return PostVisibility.public;
      case SessionVisibility.friends:
        return PostVisibility.friends;
      case SessionVisibility.private:
        return PostVisibility.private;
    }
  }

  String _getVisibilityLabel(SessionVisibility visibility) {
    switch (visibility) {
      case SessionVisibility.public:
        return 'Tous';
      case SessionVisibility.friends:
        return 'Amis';
      case SessionVisibility.private:
        return 'Personne';
    }
  }

  Future<void> _finish() async {
    // Show warning if not published
    if (!_publishedInApp) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: surfaceColor,
          title: const Text('Publier avant de quitter ?', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vous n\'avez pas encore publié ce timelapse.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Visibilité choisie : ${_getVisibilityLabel(_visibility)}',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'Voulez-vous vraiment quitter sans publier ?',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: accentColor),
              child: const Text('Quitter sans publier'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    // Pop back to the main screen
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Force refresh after a short delay to ensure screens are rebuilt
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      // Navigate to a fresh instance of the home screen to force refresh
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => StudyLapseHome(
          sessions: const [],
          onSessionFinished: (_) {},
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exporter ton timelapse')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: _player.value.aspectRatio,
                          child: VideoPlayer(_player),
                        ),
                      )
                    : const CircularProgressIndicator(color: accentColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Temps de travail : ${formatLongDuration(widget.durationSeconds)}',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Matière étudiée (affichage seulement)
                  if (widget.subject != null && widget.subject!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF252630),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.book_rounded, color: accentColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            widget.subject!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  if (widget.subject != null && widget.subject!.isNotEmpty)
                    const SizedBox(height: 12),

                  // Description personnalisée
                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ajouter une description...',
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF252630),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Visibilité
                  Row(
                    children: [
                      const Text(
                        'Visibilité : ',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      ...SessionVisibility.values.map((visibility) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: FilterChip(
                            label: Text(
                              _getVisibilityLabel(visibility),
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _visibility == visibility,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _visibility = visibility;
                                });
                              }
                            },
                            selectedColor: accentColor,
                            checkmarkColor: backgroundColor,
                            labelStyle: TextStyle(
                              color: _visibility == visibility
                                  ? backgroundColor
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                            backgroundColor: _visibility == visibility
                                ? accentColor
                                : const Color(0xFF252630),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bouton Publier in-app
                  _ExportButton(
                    icon: Icons.home_rounded,
                    label: 'Publier in-app',
                    description: 'Dans ton compte et ton feed',
                    color: accentColor,
                    isCompleted: _publishedInApp,
                    isLoading: _isPublishing,
                    onTap: _isPublishing ? null : _publishInApp,
                  ),
                  const SizedBox(height: 12),

                  // Bouton Sauvegarder dans la galerie
                  _ExportButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Galerie',
                    description: 'Enregistrer sur l\'appareil',
                    color: secondaryColor,
                    isCompleted: _savedToGallery,
                    isLoading: _isSavingToGallery,
                    onTap: _savedToGallery ? null : _saveToGallery,
                  ),
                  const SizedBox(height: 12),

                  // Bouton Réseaux sociaux
                  _ExportButton(
                    icon: Icons.share_rounded,
                    label: 'Réseaux sociaux',
                    description: 'Instagram, TikTok, WhatsApp...',
                    color: const Color(0xFFFFC777),
                    isCompleted: false,
                    isLoading: false,
                    onTap: _shareToSocialMedia,
                  ),
                  const SizedBox(height: 24),

                  // Bouton Terminer
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _finish,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Terminer'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
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

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.isCompleted,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool isCompleted;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border.all(
              color: isCompleted ? color : Colors.grey.shade700,
              width: isCompleted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: color,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        isCompleted ? Icons.check_rounded : icon,
                        color: color,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
