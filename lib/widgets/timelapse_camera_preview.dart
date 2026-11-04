import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/timelapse_capture_service.dart';
import '../main.dart';

class TimelapseCameraPreview extends StatefulWidget {
  const TimelapseCameraPreview({
    super.key,
    required this.isActive,
    required this.elapsedSeconds,
    required this.hasStarted,
    required this.isRunning,
    required this.onStart,
    required this.onTogglePause,
    required this.onStop,
    this.initialCameraDirection,
    this.onCameraDirectionChanged,
    this.onShowInfo,
    this.isPowerSavingMode = false,
    this.onTogglePowerSaving,
  });

  final bool isActive;
  final int elapsedSeconds;
  final bool hasStarted;
  final bool isRunning;

  final VoidCallback onStart;
  final VoidCallback onTogglePause;
  final ValueChanged<TimelapseCaptureResult?> onStop;
  final CameraLensDirection? initialCameraDirection;
  final ValueChanged<CameraLensDirection>? onCameraDirectionChanged;
  final VoidCallback? onShowInfo;
  final bool isPowerSavingMode;
  final VoidCallback? onTogglePowerSaving;

  @override
  State<TimelapseCameraPreview> createState() => _TimelapseCameraPreviewState();
}

class _TimelapseCameraPreviewState extends State<TimelapseCameraPreview> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  CameraLensDirection _lensDirection = CameraLensDirection.back;
  bool _isInitializing = false;
  String? _errorMessage;

  late final TimelapseCaptureService _captureService = TimelapseCaptureService(
    onCaptureError: (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Une photo n\'a pas pu être enregistrée.';
      });
    },
  );

  @override
  void initState() {
    super.initState();

    if (widget.initialCameraDirection != null) {
      _lensDirection = widget.initialCameraDirection!;
    }

    if (widget.isActive) {
      _initializeCamera();
    }
  }

  @override
  void didUpdateWidget(covariant TimelapseCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    debugPrint('StudyLapse Preview: didUpdateWidget - active: ${widget.isActive}, started: ${widget.hasStarted}, running: ${widget.isRunning}');

    if (widget.isActive && !oldWidget.isActive) {
      _initializeCamera();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disposeCamera();
    }

    if (widget.hasStarted && !_captureSessionReady) {
      debugPrint('StudyLapse Preview: Démarrage de la session de capture');
      _beginCaptureSession();
    }

    // Ne synchroniser que si la session est déjà prête
    if (_captureSessionReady &&
        (oldWidget.isRunning != widget.isRunning ||
         oldWidget.isActive != widget.isActive ||
         oldWidget.hasStarted != widget.hasStarted)) {
      _syncCaptureTimer();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing || _controller != null || !widget.isActive) {
      return;
    }

    _isInitializing = true;

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (!mounted || !widget.isActive) return;

      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Aucune caméra disponible sur cet appareil.';
        });
        return;
      }

      CameraDescription selectedCamera = _cameras.first;

      final matchingCameras = _cameras
          .where((camera) => camera.lensDirection == _lensDirection)
          .toList();

      if (matchingCameras.isNotEmpty) {
        selectedCamera = matchingCameras.first;
      } else {
        _lensDirection = selectedCamera.lensDirection;
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _controller = controller;

      await controller.initialize();

      if (!mounted || !widget.isActive) {
        await controller.dispose();

        if (identical(_controller, controller)) {
          _controller = null;
        }
        return;
      }

      setState(() {
        _errorMessage = null;
      });
      _captureService.setCameraController(controller);
      _syncCaptureTimer();
    } on CameraException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = switch (error.code) {
          'CameraAccessDenied' =>
            'Autorise l’accès à la caméra dans les paramètres.',
          'CameraAccessDeniedWithoutPrompt' =>
            'L’accès à la caméra est refusé. Vérifie les paramètres.',
          'CameraAccessRestricted' =>
            'L’accès à la caméra est restreint sur cet appareil.',
          _ => 'Impossible de démarrer la caméra (${error.code}).',
        };
      });

      await _disposeCamera();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Une erreur est survenue lors du démarrage.';
      });

      await _disposeCamera();
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_isInitializing || !(_controller?.value.isInitialized ?? false)) {
      return;
    }

    final otherDirection = _lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final hasOtherCamera = _cameras.any(
      (camera) => camera.lensDirection == otherDirection,
    );

    if (!hasOtherCamera) {
      setState(() {
        _errorMessage = 'Aucune autre caméra disponible sur cet appareil.';
      });
      return;
    }

    final oldController = _controller;

    _captureService.pause();
    _captureService.setCameraController(null);

    _controller = null;
    _lensDirection = otherDirection;

    setState(() {
      _errorMessage = null;
    });

    await oldController?.dispose();

    widget.onCameraDirectionChanged?.call(_lensDirection);

    if (mounted && widget.isActive) {
      await _initializeCamera();
    }
  }

  Future<void> _disposeCamera() async {
    _captureService.pause();
    _captureService.setCameraController(null);

    final controller = _controller;
    _controller = null;

    if (controller != null) {
      await controller.dispose();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _captureService.pause();
    _captureService.setCameraController(null);

    final controller = _controller;
    _controller = null;

    if (controller != null) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _beginCaptureSession() async {
    if (_captureSessionReady) return;

    final pending = _captureSetupFuture;

    if (pending != null) {
      debugPrint('StudyLapse Preview: Session de capture déjà en préparation, attente...');
      try {
        await pending;
      } catch (_) {
        // L'erreur est traitée par la préparation.
      }
      return;
    }

    debugPrint('StudyLapse Preview: Démarrage de la préparation de la session de capture');
    final setup = _prepareCaptureSession();
    _captureSetupFuture = setup;

    try {
      await setup;
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Impossible de préparer les captures.';
      });
    } finally {
      if (identical(_captureSetupFuture, setup)) {
        _captureSetupFuture = null;
      }
    }
  }

  Future<void> _prepareCaptureSession() async {
    debugPrint('StudyLapse Preview: beginSession appelé');
    await _captureService.beginSession();
    debugPrint('StudyLapse Preview: beginSession terminé');

    _captureSessionReady = true;
    debugPrint('StudyLapse Preview: _captureSessionReady = true');
    _captureService.setCameraController(_controller);

    // Synchroniser après que la session soit prête
    _syncCaptureTimer();
  }

  void _syncCaptureTimer() {
    if (!_captureSessionReady) {
      debugPrint('StudyLapse Preview: Session de capture non prête');
      return;
    }

    final controller = _controller;
    _captureService.setCameraController(controller);

    final canCapture =
        widget.isActive &&
        widget.hasStarted &&
        widget.isRunning &&
        (controller?.value.isInitialized ?? false);

    debugPrint('StudyLapse Preview: Sync capture - active: ${widget.isActive}, started: ${widget.hasStarted}, running: ${widget.isRunning}, canCapture: $canCapture');

    if (canCapture) {
      _captureService.resume();
    } else {
      _captureService.pause();
    }
  }

  Future<void> _handleStop() async {
    _captureService.pause();

    final pending = _captureSetupFuture;

    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // La session peut tout de même être arrêtée.
      }
    }

    final result = await _captureService.finishSession();
    _captureSessionReady = false;

    if (!mounted) return;

    widget.onStop(result);
  }

  bool _captureSessionReady = false;
  Future<void>? _captureSetupFuture;

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        final iconSize = (shortestSide * 0.075).clamp(24.0, 34.0);
        final buttonSize = (shortestSide * 0.15).clamp(48.0, 66.0);
        final smallButtonSize = (shortestSide * 0.12).clamp(44.0, 56.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPreview(controller),

                // Chronomètre en haut, uniquement après le démarrage.
                if (widget.hasStarted)
                  Positioned(
                    top: 18,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          formatDuration(widget.elapsedSeconds),
                          key: const ValueKey('session_timer'),
                          textScaler: const TextScaler.linear(1),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (shortestSide * 0.075).clamp(22.0, 34.0),
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Commandes au bas de l'aperçu.
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: widget.hasStarted
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _roundButton(
                                icon: Icons.cameraswitch_rounded,
                                size: smallButtonSize,
                                iconSize: iconSize,
                                tooltip: 'Changer de caméra',
                                onPressed: _isInitializing
                                    ? null
                                    : _switchCamera,
                              ),
                              SizedBox(width: shortestSide * 0.07),
                              _roundButton(
                                icon: widget.isRunning
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: buttonSize,
                                iconSize: iconSize * 1.15,
                                tooltip: widget.isRunning
                                    ? 'Mettre en pause'
                                    : 'Reprendre',
                                onPressed: widget.onTogglePause,
                                backgroundColor: accentColor,
                                foregroundColor: backgroundColor,
                              ),
                              SizedBox(width: shortestSide * 0.07),
                              _roundButton(
                                icon: Icons.stop_rounded,
                                size: smallButtonSize,
                                iconSize: iconSize,
                                tooltip: 'Arrêter la session',
                                onPressed: _handleStop,
                                backgroundColor: const Color(0xFFE94F5D),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _roundButton(
                                icon: Icons.cameraswitch_rounded,
                                size: smallButtonSize,
                                iconSize: iconSize,
                                tooltip: 'Changer de caméra',
                                onPressed: _isInitializing
                                    ? null
                                    : _switchCamera,
                              ),
                              const SizedBox(width: 28),
                              _roundButton(
                                icon: Icons.fiber_manual_record_rounded,
                                size: buttonSize,
                                iconSize: iconSize * 1.2,
                                tooltip: 'Démarrer l’enregistrement',
                                onPressed: widget.onStart,
                                backgroundColor: const Color(0xFFE94F5D),
                              ),
                              const SizedBox(width: 28),
                              _roundButton(
                                icon: Icons.info_outline_rounded,
                                size: smallButtonSize,
                                iconSize: iconSize,
                                tooltip: 'Informations',
                                onPressed: widget.onShowInfo,
                              ),
                            ],
                          ),
                  ),
                ),

                // Bouton économie pendant l'enregistrement
                if (widget.hasStarted && !widget.isPowerSavingMode)
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: IconButton(
                      icon: Icon(
                        widget.isPowerSavingMode
                            ? Icons.battery_saver
                            : Icons.battery_alert,
                        color: widget.isPowerSavingMode
                            ? Colors.green
                            : Colors.white70,
                      ),
                      onPressed: widget.onTogglePowerSaving,
                      style: IconButton.styleFrom(
                        backgroundColor: surfaceColor,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),

                if (_errorMessage != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 70,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  ),

                if (widget.hasStarted && !widget.isRunning)
                  Positioned(
                    top: 76,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'EN PAUSE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview(CameraController? controller) {
    if (!widget.isActive) {
      return const Center(
        child: Text('Caméra inactive', style: TextStyle(color: Colors.white70)),
      );
    }

    if (controller?.value.isInitialized ?? false) {
      final cameraController = controller!;
      final previewSize = cameraController.value.previewSize;

      if (previewSize == null) {
        return CameraPreview(cameraController);
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;

          // Le flux caméra peut être fourni dans l'orientation du capteur.
          // On adapte le cadre sans étirer l'image.
          final previewWidth = isLandscape
              ? previewSize.width
              : previewSize.height;
          final previewHeight = isLandscape
              ? previewSize.height
              : previewSize.width;

          return ClipRect(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: CameraPreview(cameraController),
                ),
              ),
            ),
          );
        },
      );
    }

    if (_errorMessage != null) {
      return const Center(
        child: Icon(
          Icons.no_photography_outlined,
          color: Colors.white54,
          size: 48,
        ),
      );
    }

    return const Center(child: CircularProgressIndicator(color: accentColor));
  }

  Widget _roundButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required String tooltip,
    required VoidCallback? onPressed,
    Color backgroundColor = const Color(0xCC252630),
    Color foregroundColor = Colors.white,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: iconSize),
          style: IconButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            disabledBackgroundColor: const Color(0x66252630),
            disabledForegroundColor: Colors.white38,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
