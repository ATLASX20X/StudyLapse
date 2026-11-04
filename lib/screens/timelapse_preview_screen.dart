import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../services/timelapse_capture_service.dart';
import '../services/timelapse_video_service.dart' as video_service;
import 'timelapse_export_screen.dart';

typedef TimelapseOrientation = video_service.TimelapseOrientation;
typedef TimelapseVideoService = video_service.TimelapseVideoService;

class TimelapsePreviewScreen extends StatefulWidget {
  const TimelapsePreviewScreen({
    super.key,
    required this.captureResult,
    required this.durationSeconds,
    required this.orientation,
  });

  final TimelapseCaptureResult captureResult;
  final int durationSeconds;
  final TimelapseOrientation orientation;

  @override
  State<TimelapsePreviewScreen> createState() => _TimelapsePreviewScreenState();
}

class _TimelapsePreviewScreenState extends State<TimelapsePreviewScreen> {
  final TimelapseVideoService _videoService = TimelapseVideoService();

  VideoPlayerController? _player;
  String? _videoPath;
  String? _errorMessage;

  bool _isLoading = false;
  int _selectedVideoDuration = 15;
  String _selectedSubject = '';
  video_service.WatermarkTemplate _selectedTemplate = video_service.WatermarkTemplate.stacked;
  video_service.WatermarkRotation _selectedRotation = video_service.WatermarkRotation.none;

  final TextEditingController _subjectController = TextEditingController();
  final FocusNode _subjectFocusNode = FocusNode();
  List<Subject> _filteredSubjects = Subject.predefinedSubjects;
  bool _showSubjectDropdown = false;

  @override
  void initState() {
    super.initState();
    _subjectController.addListener(_onSubjectChanged);
  }

  void _onSubjectChanged() {
    setState(() {
      _filteredSubjects = Subject.searchSubjects(_subjectController.text);
      _showSubjectDropdown = _subjectController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    _subjectController.dispose();
    _subjectFocusNode.dispose();
    super.dispose();
  }

  Future<void> _generatePreviewVideo() async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    VideoPlayerController? newPlayer;

    try {
      debugPrint('StudyLapse UI: début génération preview');

      final generatedPath = await _videoService
          .generateVideo(
            imagePaths: widget.captureResult.imagePaths,
            elapsedTimes: widget.captureResult.elapsedTimes,
            sessionDuration: widget.captureResult.elapsedTimes.last,
            sessionStartTime: widget.captureResult.startTime,
            sessionEndTime: widget.captureResult.endTime,
            videoDurationSeconds: _selectedVideoDuration,
            orientation: widget.orientation,
            title: 'StudyLapse',
            subject: _selectedSubject,
            template: _selectedTemplate,
            rotation: _selectedRotation,
          )
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              throw TimeoutException(
                'La génération de la vidéo a dépassé 2 minutes.',
              );
            },
          );

      _videoPath = generatedPath;
      debugPrint('StudyLapse UI: génération terminée, $_videoPath');

      final videoFile = File(generatedPath);
      debugPrint('StudyLapse UI: fichier existe: ${videoFile.existsSync()}, taille: ${videoFile.existsSync() ? videoFile.lengthSync() : 'N/A'}');

      // Attendre un court instant pour s'assurer que le fichier est bien libéré par FFmpeg
      await Future.delayed(const Duration(milliseconds: 100));

      newPlayer = VideoPlayerController.file(videoFile);

      debugPrint('StudyLapse UI: initialisation du lecteur');
      try {
        await newPlayer.initialize().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException(
              'Le lecteur vidéo ne répond pas après 15 secondes.',
            );
          },
        );
      } catch (e) {
        debugPrint('StudyLapse UI: erreur initialisation lecteur: $e');
        rethrow;
      }
      debugPrint('StudyLapse UI: lecteur initialisé');

      await newPlayer.setLooping(true);
      debugPrint('StudyLapse UI: boucle activée');

      if (!mounted) {
        await newPlayer.dispose();
        return;
      }

      final oldPlayer = _player;
      _player = newPlayer;
      newPlayer = null;

      await oldPlayer?.dispose();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }

      debugPrint('StudyLapse UI: lancement de la lecture');
      await _player!.play().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'La lecture vidéo ne démarre pas après 10 secondes.',
          );
        },
      );
      debugPrint('StudyLapse UI: lecture lancée');
    } catch (error, stackTrace) {
      debugPrint('StudyLapse UI: erreur $error');
      debugPrintStack(stackTrace: stackTrace);

      await newPlayer?.dispose();

      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de lire la vidéo : $error';
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createFinalVideo() async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('StudyLapse UI: début génération vidéo finale');

      final generatedPath = await _videoService
          .generateVideo(
            imagePaths: widget.captureResult.imagePaths,
            elapsedTimes: widget.captureResult.elapsedTimes,
            sessionDuration: widget.captureResult.elapsedTimes.last,
            sessionStartTime: widget.captureResult.startTime,
            sessionEndTime: widget.captureResult.endTime,
            videoDurationSeconds: _selectedVideoDuration,
            orientation: widget.orientation,
            title: 'StudyLapse',
            subject: _selectedSubject,
            template: _selectedTemplate,
            rotation: _selectedRotation,
          )
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              throw TimeoutException(
                'La génération de la vidéo a dépassé 2 minutes.',
              );
            },
          );

      debugPrint('StudyLapse UI: vidéo finale générée, $generatedPath');

      if (!mounted) return;

      await _videoService.deleteCaptureDirectory(widget.captureResult.directoryPath);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TimelapseExportScreen(
            videoPath: generatedPath,
            durationSeconds: widget.durationSeconds,
            subject: _selectedSubject,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('StudyLapse UI: erreur $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de créer la vidéo : $error';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;

    return Scaffold(
      appBar: AppBar(title: const Text('Personnaliser ton timelapse')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Session terminée !',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Temps de travail : '
              '${formatLongDuration(widget.durationSeconds)}',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),

            const Text(
              'Durée de la vidéo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _selectedVideoDuration.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 5,
                    label: '$_selectedVideoDuration secondes',
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _selectedVideoDuration = value.round();
                              _videoPath = null;
                              _errorMessage = null;
                            });
                            final oldPlayer = _player;
                            _player = null;
                            oldPlayer?.dispose();
                          },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '$_selectedVideoDuration s',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Vidéo finale à 30 images par seconde.',
              style: TextStyle(color: Colors.grey.shade400, height: 1.5),
            ),
            const SizedBox(height: 24),

            const Text(
              'Matière étudiée',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _subjectController,
                  focusNode: _subjectFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Rechercher ou saisir une matière',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _selectedSubject.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _subjectController.clear();
                              setState(() {
                                _selectedSubject = '';
                                _filteredSubjects = Subject.predefinedSubjects;
                                _showSubjectDropdown = false;
                              });
                            },
                          )
                        : null,
                  ),
                  onTap: () {
                    setState(() {
                      _showSubjectDropdown = true;
                    });
                  },
                ),
                if (_showSubjectDropdown && _filteredSubjects.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredSubjects.length,
                      itemBuilder: (context, index) {
                        final subject = _filteredSubjects[index];
                        return ListTile(
                          leading: Text(
                            subject.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(subject.name),
                          onTap: () {
                            setState(() {
                              _selectedSubject = subject.name;
                              _subjectController.text = subject.name;
                              _showSubjectDropdown = false;
                              _subjectFocusNode.unfocus();
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Style de filigrane',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TemplateOption(
                        template: video_service.WatermarkTemplate.none,
                        selectedTemplate: _selectedTemplate,
                        label: 'Aucun',
                        icon: Icons.block,
                        onTap: () {
                          setState(() {
                            _selectedTemplate = video_service.WatermarkTemplate.none;
                            _videoPath = null;
                            _errorMessage = null;
                          });
                          final oldPlayer = _player;
                          _player = null;
                          oldPlayer?.dispose();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TemplateOption(
                        template: video_service.WatermarkTemplate.stacked,
                        selectedTemplate: _selectedTemplate,
                        label: 'Empilé',
                        icon: Icons.view_agenda,
                        onTap: () {
                          setState(() {
                            _selectedTemplate = video_service.WatermarkTemplate.stacked;
                            _videoPath = null;
                            _errorMessage = null;
                          });
                          final oldPlayer = _player;
                          _player = null;
                          oldPlayer?.dispose();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TemplateOption(
                        template: video_service.WatermarkTemplate.circle,
                        selectedTemplate: _selectedTemplate,
                        label: 'Cercle',
                        icon: Icons.circle_outlined,
                        onTap: () {
                          setState(() {
                            _selectedTemplate = video_service.WatermarkTemplate.circle;
                            _videoPath = null;
                            _errorMessage = null;
                          });
                          final oldPlayer = _player;
                          _player = null;
                          oldPlayer?.dispose();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TemplateOption(
                        template: video_service.WatermarkTemplate.clock,
                        selectedTemplate: _selectedTemplate,
                        label: 'Horloge',
                        icon: Icons.access_time,
                        onTap: () {
                          setState(() {
                            _selectedTemplate = video_service.WatermarkTemplate.clock;
                            _videoPath = null;
                            _errorMessage = null;
                          });
                          final oldPlayer = _player;
                          _player = null;
                          oldPlayer?.dispose();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TemplateOption(
                        template: video_service.WatermarkTemplate.timer,
                        selectedTemplate: _selectedTemplate,
                        label: 'Chrono',
                        icon: Icons.timer,
                        onTap: () {
                          setState(() {
                            _selectedTemplate = video_service.WatermarkTemplate.timer;
                            _videoPath = null;
                            _errorMessage = null;
                          });
                          final oldPlayer = _player;
                          _player = null;
                          oldPlayer?.dispose();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TemplateOption(
                        template: video_service.WatermarkTemplate.progressbar,
                        selectedTemplate: _selectedTemplate,
                        label: 'Barre',
                        icon: Icons.linear_scale,
                        onTap: () {
                          setState(() {
                            _selectedTemplate = video_service.WatermarkTemplate.progressbar;
                            _videoPath = null;
                            _errorMessage = null;
                          });
                          final oldPlayer = _player;
                          _player = null;
                          oldPlayer?.dispose();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Rotation du filigrane',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RotationOption(
                    rotation: video_service.WatermarkRotation.none,
                    selectedRotation: _selectedRotation,
                    label: 'Aucune',
                    icon: Icons.screen_rotation,
                    onTap: () {
                      setState(() {
                        _selectedRotation = video_service.WatermarkRotation.none;
                        _videoPath = null;
                        _errorMessage = null;
                      });
                      final oldPlayer = _player;
                      _player = null;
                      oldPlayer?.dispose();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RotationOption(
                    rotation: video_service.WatermarkRotation.clockwise90,
                    selectedRotation: _selectedRotation,
                    label: '+90°',
                    icon: Icons.rotate_right,
                    onTap: () {
                      setState(() {
                        _selectedRotation = video_service.WatermarkRotation.clockwise90;
                        _videoPath = null;
                        _errorMessage = null;
                      });
                      final oldPlayer = _player;
                      _player = null;
                      oldPlayer?.dispose();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RotationOption(
                    rotation: video_service.WatermarkRotation.counterclockwise90,
                    selectedRotation: _selectedRotation,
                    label: '-90°',
                    icon: Icons.rotate_left,
                    onTap: () {
                      setState(() {
                        _selectedRotation = video_service.WatermarkRotation.counterclockwise90;
                        _videoPath = null;
                        _errorMessage = null;
                      });
                      final oldPlayer = _player;
                      _player = null;
                      oldPlayer?.dispose();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RotationOption(
                    rotation: video_service.WatermarkRotation.clockwise180,
                    selectedRotation: _selectedRotation,
                    label: '180°',
                    icon: Icons.flip,
                    onTap: () {
                      setState(() {
                        _selectedRotation = video_service.WatermarkRotation.clockwise180;
                        _videoPath = null;
                        _errorMessage = null;
                      });
                      final oldPlayer = _player;
                      _player = null;
                      oldPlayer?.dispose();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(
                child: CircularProgressIndicator(color: accentColor),
              ),
              const SizedBox(height: 20),
              const Center(child: Text('Génération de la preview…')),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${widget.captureResult.imageCount} photos capturées',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
            ] else if (_errorMessage != null) ...[
              const Icon(
                Icons.video_camera_back_outlined,
                size: 64,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _generatePreviewVideo,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ] else if (player != null && player.value.isInitialized) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: player.value.aspectRatio,
                  child: VideoPlayer(player),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      if (player.value.isPlaying) {
                        await player.pause();
                      } else {
                        await player.play();
                      }

                      if (mounted) setState(() {});
                    },
                    icon: Icon(
                      player.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      player.value.isPlaying ? 'Pause' : 'Lire',
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _generatePreviewVideo,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Rafraîchir'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _createFinalVideo,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Créer mon timelapse'),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else ...[
              Center(
                child: Text(
                  '${widget.captureResult.imageCount} photos prêtes '
                  'pour le montage',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _generatePreviewVideo,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Aperçu'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateOption extends StatelessWidget {
  const _TemplateOption({
    required this.template,
    required this.selectedTemplate,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final video_service.WatermarkTemplate template;
  final video_service.WatermarkTemplate selectedTemplate;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = template == selectedTemplate;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.2) : surfaceColor,
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade700,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : Colors.grey.shade400,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : Colors.grey.shade300,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RotationOption extends StatelessWidget {
  const _RotationOption({
    required this.rotation,
    required this.selectedRotation,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final video_service.WatermarkRotation rotation;
  final video_service.WatermarkRotation selectedRotation;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = rotation == selectedRotation;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.2) : surfaceColor,
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade700,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : Colors.grey.shade300,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
