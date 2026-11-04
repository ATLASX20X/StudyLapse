import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TimelapseCaptureResult {
  const TimelapseCaptureResult({
    required this.directoryPath,
    required this.imagePaths,
    required this.elapsedTimes,
    required this.startTime,
    required this.endTime,
  }) : assert(imagePaths.length == elapsedTimes.length);

  final String directoryPath;

  /// Chemins des images, dans l'ordre des captures.
  final List<String> imagePaths;

  /// Temps écoulé depuis le début de la session active pour chaque image.
  /// Chaque valeur correspond à l'image située au même index dans imagePaths.
  final List<Duration> elapsedTimes;

  /// Timestamp de début de l'enregistrement
  final DateTime startTime;

  /// Timestamp de fin de l'enregistrement
  final DateTime endTime;

  int get imageCount => imagePaths.length;
}

class TimelapseCaptureService {
  TimelapseCaptureService({this.onCaptureError});

  final void Function(Object error)? onCaptureError;

  CameraController? _cameraController;
  Directory? _sessionDirectory;
  Timer? _timer;
  Future<void>? _activeCapture;

  final Stopwatch _stopwatch = Stopwatch();
  final List<String> _imagePaths = [];
  final List<Duration> _elapsedTimes = [];

  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;

  int _nextFrame = 0;
  Duration _lastCaptureAt = Duration.zero;
  bool _isDisposed = false;

  static const Duration _checkInterval = Duration(milliseconds: 200);

  bool get isCapturing => _timer?.isActive ?? false;

  int get imageCount => _imagePaths.length;

  Duration get elapsed => _stopwatch.elapsed;

  /// L'intervalle augmente au fil de la session.
  Duration _intervalFor(Duration elapsed) {
    // Pour s'assurer qu'on a au moins une photo, commencer avec un intervalle très court
    if (elapsed < const Duration(seconds: 2)) {
      return const Duration(milliseconds: 200);
    }
    if (elapsed < const Duration(minutes: 2)) {
      return const Duration(milliseconds: 500);
    }
    if (elapsed < const Duration(minutes: 5)) {
      return const Duration(seconds: 1);
    }
    if (elapsed < const Duration(minutes: 15)) {
      return const Duration(seconds: 2);
    }
    if (elapsed < const Duration(minutes: 30)) {
      return const Duration(seconds: 3);
    }
    return const Duration(seconds: 5);
  }

  Future<void> beginSession() async {
    _ensureNotDisposed();

    pause();

    final activeCapture = _activeCapture;
    if (activeCapture != null) {
      await activeCapture;
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final sessionsDirectory = Directory(
      '${appDirectory.path}/StudyLapse/sessions',
    );

    await sessionsDirectory.create(recursive: true);

    final sessionDirectory = Directory(
      '${sessionsDirectory.path}/session_'
      '${DateTime.now().microsecondsSinceEpoch}',
    );

    await sessionDirectory.create();

    _sessionDirectory = sessionDirectory;
    _imagePaths.clear();
    _elapsedTimes.clear();
    _nextFrame = 0;
    _lastCaptureAt = Duration.zero;
    _stopwatch
      ..reset()
      ..stop();
  }

  void setCameraController(CameraController? controller) {
    if (_isDisposed) return;
    _cameraController = controller;
  }

  void resume() {
    _ensureNotDisposed();

    if (_sessionDirectory == null) {
      throw StateError('Il faut appeler beginSession() avant resume().');
    }

    if (_timer?.isActive ?? false) {
      debugPrint('StudyLapse Capture: Timer déjà actif');
      return;
    }

    debugPrint('StudyLapse Capture: Démarrage du timer de capture');
    _sessionStartTime = DateTime.now();
    _stopwatch.start();

    _timer = Timer.periodic(_checkInterval, (_) {
      final now = _stopwatch.elapsed;
      final interval = _intervalFor(now);

      if (now - _lastCaptureAt < interval) return;

      _scheduleCapture();
    });
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _sessionEndTime = DateTime.now();
  }

  void _scheduleCapture() {
    if (_isDisposed || _activeCapture != null) return;

    final capture = _captureOne();
    _activeCapture = capture;

    capture.whenComplete(() {
      if (identical(_activeCapture, capture)) {
        _activeCapture = null;
      }
    });
  }

  Future<void> _captureOne() async {
    final controller = _cameraController;
    final directory = _sessionDirectory;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        directory == null) {
      return;
    }

    final captureTime = _stopwatch.elapsed;
    _lastCaptureAt = captureTime;

    try {
      final photo = await controller.takePicture();

      if (_isDisposed || !identical(directory, _sessionDirectory)) {
        return;
      }

      final filename = 'frame_${_nextFrame.toString().padLeft(6, '0')}.jpg';

      final destination = File('${directory.path}/$filename');
      await File(photo.path).copy(destination.path);

      _imagePaths.add(destination.path);
      _elapsedTimes.add(captureTime);
      _nextFrame++;

      debugPrint('StudyLapse Capture: Photo capturée #$_nextFrame, temps: $captureTime');
    } catch (error) {
      debugPrint('StudyLapse Capture: Erreur de capture: $error');
      if (!_isDisposed) {
        onCaptureError?.call(error);
      }
    }
  }

  Future<TimelapseCaptureResult?> finishSession() async {
    pause();

    final activeCapture = _activeCapture;
    if (activeCapture != null) {
      await activeCapture;
    }

    final directory = _sessionDirectory;
    if (directory == null) return null;

    final result = TimelapseCaptureResult(
      directoryPath: directory.path,
      imagePaths: List.unmodifiable(_imagePaths),
      elapsedTimes: List.unmodifiable(_elapsedTimes),
      startTime: _sessionStartTime ?? DateTime.now(),
      endTime: _sessionEndTime ?? DateTime.now(),
    );

    _sessionDirectory = null;
    _cameraController = null;
    _imagePaths.clear();
    _elapsedTimes.clear();
    _nextFrame = 0;
    _lastCaptureAt = Duration.zero;

    return result;
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('Le service de capture a été libéré.');
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    pause();

    final activeCapture = _activeCapture;
    if (activeCapture != null) {
      await activeCapture;
    }

    _cameraController = null;
    _sessionDirectory = null;
    _imagePaths.clear();
    _elapsedTimes.clear();
    _isDisposed = true;
  }
}
