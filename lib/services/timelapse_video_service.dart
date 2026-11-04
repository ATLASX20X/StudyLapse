import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:path_provider/path_provider.dart';

enum TimelapseOrientation { portrait, landscape }

enum WatermarkTemplate {
  none,
  stacked,
  circle,
  clock,
  timer,
  progressbar,
}

enum WatermarkRotation {
  none,
  clockwise90,
  counterclockwise90,
  clockwise180,
}

class TimelapseVideoService {
  static const int framesPerSecond = 30;
  static const int minimumVideoDuration = 5;
  static const int maximumVideoDuration = 30;

  static const int _portraitWidth = 720;
  static const int _portraitHeight = 1280;
  static const int _landscapeWidth = 1280;
  static const int _landscapeHeight = 720;

  Future<String> generateVideo({
    required List<String> imagePaths,
    List<Duration>? elapsedTimes,
    Duration? sessionDuration,
    DateTime? sessionStartTime,
    DateTime? sessionEndTime,
    int videoDurationSeconds = 15,
    TimelapseOrientation orientation = TimelapseOrientation.portrait,
    String title = 'StudyLapse',
    String subject = '',
    WatermarkTemplate template = WatermarkTemplate.stacked,
    WatermarkRotation rotation = WatermarkRotation.none,
  }) async {
    if (imagePaths.isEmpty) {
      throw StateError('Aucune photo disponible pour le montage.');
    }

    if (videoDurationSeconds < minimumVideoDuration ||
        videoDurationSeconds > maximumVideoDuration) {
      throw RangeError.range(
        videoDurationSeconds,
        minimumVideoDuration,
        maximumVideoDuration,
        'videoDurationSeconds',
      );
    }

    if (elapsedTimes != null && elapsedTimes.length != imagePaths.length) {
      throw ArgumentError(
        'Chaque photo doit posséder un horodatage correspondant.',
      );
    }

    for (final path in imagePaths) {
      if (!await File(path).exists()) {
        throw StateError('Photo introuvable : $path');
      }
    }

    if (elapsedTimes != null) {
      for (var i = 1; i < elapsedTimes.length; i++) {
        if (elapsedTimes[i] < elapsedTimes[i - 1]) {
          throw ArgumentError('Les horodatages doivent être chronologiques.');
        }
      }
    }

    final timer = Stopwatch()..start();
    final totalFrames = videoDurationSeconds * framesPerSecond;

    final frames = _buildOutputFrames(
      imagePaths: imagePaths,
      elapsedTimes: elapsedTimes,
      sessionDuration: sessionDuration,
      totalFrames: totalFrames,
    );

    final width = orientation == TimelapseOrientation.portrait
        ? _portraitWidth
        : _landscapeWidth;
    final height = orientation == TimelapseOrientation.portrait
        ? _portraitHeight
        : _landscapeHeight;

    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/StudyLapse/videos');
    await dir.create(recursive: true);

    final id = DateTime.now().microsecondsSinceEpoch;
    final output = File('${dir.path}/timelapse_$id.mp4');
    final manifestFile = File('${dir.path}/input_$id.txt');
    final overlayFile = File('${dir.path}/overlay_$id.png');

    try {
      // Regroupe les répétitions consécutives dans le manifeste.
      // Exemple : 90 occurrences identiques deviennent une seule entrée
      // avec une durée de 3 secondes.
      final manifest = StringBuffer();
      var runPath = frames.first;
      var runLength = 1;

      void writeRun(String path, int count) {
        manifest.writeln("file '${_escapePath(path)}'");
        final duration = count / framesPerSecond;
        manifest.writeln('duration ${duration.toStringAsFixed(6)}');
      }

      for (var i = 1; i < frames.length; i++) {
        if (frames[i] == runPath) {
          runLength++;
        } else {
          writeRun(runPath, runLength);
          runPath = frames[i];
          runLength = 1;
        }
      }

      writeRun(runPath, runLength);

      // FFmpeg concat nécessite une dernière entrée pour stabiliser
      // la durée de la dernière image.
      manifest.writeln("file '${_escapePath(frames.last)}'");

      await manifestFile.writeAsString(manifest.toString());

      // Pour les templates animés, générer une séquence courte d'animation
      final needsAnimation = template == WatermarkTemplate.circle ||
                            template == WatermarkTemplate.clock ||
                            template == WatermarkTemplate.timer ||
                            template == WatermarkTemplate.progressbar;

      final encodingOptions = '-c:v mpeg4 -q:v 3';

      if (needsAnimation) {
        // Générer 60 frames d'animation (2 secondes à 30 fps) pour une animation plus fluide
        final animationDir = Directory('${dir.path}/animation_$id');
        await animationDir.create(recursive: true);
        
        final scale = width / 720.0;
        final animationFrames = 60; // 2 secondes d'animation pour plus de fluidité
        final animationFiles = <File>[];
        
        for (int i = 0; i < animationFrames; i++) {
          final progress = i / (animationFrames - 1); // 0.0 à 1.0
          final currentDuration = (sessionDuration ?? Duration.zero) * progress;
          
          final currentTime = switch (template) {
            WatermarkTemplate.clock => Duration.zero,
            WatermarkTemplate.timer => currentDuration,
            _ => currentDuration,
          };

          final animFile = File('${animationDir.path}/frame_${i.toString().padLeft(3, '0')}.png');
          await _writeSingleOverlay(
            animFile,
            width,
            height,
            scale,
            title,
            subject,
            sessionDuration ?? Duration.zero,
            template,
            rotation,
            videoDurationSeconds,
            orientation,
            sessionStartTime,
            sessionEndTime,
            progress: progress,
            currentTime: currentTime,
          );
          animationFiles.add(animFile);
        }
        
        // Créer un manifeste pour l'animation qui répète les frames pour couvrir toute la vidéo
        final animManifestFile = File('${animationDir.path}/manifest.txt');
        final animManifest = StringBuffer();
        
        // Chaque frame d'animation doit être répétée pour couvrir la durée totale
        final framesPerAnimFrame = (totalFrames / animationFrames).ceil();
        for (int i = 0; i < animationFrames; i++) {
          animManifest.writeln("file '${_escapePath(animationFiles[i].path)}'");
          animManifest.writeln('duration ${(framesPerAnimFrame / framesPerSecond).toStringAsFixed(6)}');
        }
        // Dernière frame pour boucler proprement
        animManifest.writeln("file '${_escapePath(animationFiles.last.path)}'");
        await animManifestFile.writeAsString(animManifest.toString());
        
        // Utiliser le manifeste d'animation comme overlay
        final filter =
            '[0:v]'
            'scale=$width:$height:'
            'force_original_aspect_ratio=increase:flags=fast_bilinear,'
            'crop=$width:$height,setsar=1[base];'
            '[1:v]scale=$width:$height,format=rgba[mark];'
            '[base][mark]overlay=0:0:shortest=1,'
            'fps=$framesPerSecond,format=yuv420p[v]';

        final commandParts = [
          '-hide_banner',
          '-loglevel error',
          '-y',
          '-f concat',
          '-safe 0',
          '-i ${_quote(manifestFile.path)}',
          '-f concat',
          '-safe 0',
          '-i ${_quote(animManifestFile.path)}',
          '-filter_complex "$filter"',
          '-map "[v]"',
          '-frames:v $totalFrames',
          '-r $framesPerSecond',
          encodingOptions,
          '-pix_fmt yuv420p',
          '-an',
          '-movflags +faststart',
          _quote(output.path),
        ];

        final command = commandParts.join(' ');

        debugPrint(
          'StudyLapse: début encodage vidéo animée '
          '(${animationFiles.length} frames animés, ${width}x$height).',
        );

        final encodeTimer = Stopwatch()..start();
        final session = await FFmpegKit.execute(command);
        encodeTimer.stop();

        final code = await session.getReturnCode();
        final fileSize = await output.exists() ? await output.length() : 0;
        final success =
            ReturnCode.isSuccess(code) &&
            await output.exists() &&
            fileSize > 10240;

        debugPrint(
          'StudyLapse: encodage terminé en '
          '${encodeTimer.elapsedMilliseconds} ms '
          '(succès=$success, taille=$fileSize octets).',
        );

        if (!success) {
          final logs = await session.getAllLogsAsString();
          throw StateError('Échec de l\'encodage, code $code. $logs');
        }

        // Nettoyer les fichiers temporaires
        await animationDir.delete(recursive: true);
      } else {
        // Template statique : générer une seule image PNG
        await _writeOverlay(
          overlayFile,
          width: width,
          height: height,
          title: title,
          subject: subject,
          duration: sessionDuration ?? Duration.zero,
          template: template,
          rotation: rotation,
          videoDurationSeconds: videoDurationSeconds,
          orientation: orientation,
          sessionStartTime: sessionStartTime,
          sessionEndTime: sessionEndTime,
        );

        // Les dimensions finales sont fixes et paires.
        // fast_bilinear réduit le coût du redimensionnement.
        final filter =
            '[0:v]'
            'scale=$width:$height:'
            'force_original_aspect_ratio=increase:flags=fast_bilinear,'
            'crop=$width:$height,setsar=1[base];'
            '[1:v]format=rgba[mark];'
            '[base][mark]overlay=0:0:shortest=1,'
            'fps=$framesPerSecond,format=yuv420p[v]';

        final inputOverlay = _quote(overlayFile.path);

        final commandParts = [
          '-hide_banner',
          '-loglevel error',
          '-y',
          '-f concat',
          '-safe 0',
          '-i ${_quote(manifestFile.path)}',
          '-loop 1',
          '-framerate $framesPerSecond',
          '-i $inputOverlay',
          '-filter_complex "$filter"',
          '-map "[v]"',
          '-frames:v $totalFrames',
          '-r $framesPerSecond',
          '-c:v mpeg4 -q:v 3',
          '-pix_fmt yuv420p',
          '-an',
          '-movflags +faststart',
          _quote(output.path),
        ];

        final command = commandParts.join(' ');

        debugPrint(
          'StudyLapse: début encodage vidéo '
          '(${frames.length} frames, ${width}x$height).',
        );

        final encodeTimer = Stopwatch()..start();
        final session = await FFmpegKit.execute(command);
        encodeTimer.stop();

        final code = await session.getReturnCode();
        final fileSize = await output.exists() ? await output.length() : 0;
        final success =
            ReturnCode.isSuccess(code) &&
            await output.exists() &&
            fileSize > 10240; // Minimum 10KB pour une vidéo valide

        debugPrint(
          'StudyLapse: encodage terminé en '
          '${encodeTimer.elapsedMilliseconds} ms '
          '(succès=$success, taille=$fileSize octets).',
        );

        if (!success) {
          final logs = await session.getAllLogsAsString();
          throw StateError('Échec de l\'encodage, code $code. $logs');
        }
      }

      debugPrint(
        'StudyLapse: génération totale '
        '${timer.elapsedMilliseconds} ms.',
      );

      return output.path;
    } catch (_) {
      if (await output.exists()) {
        await output.delete();
      }
      rethrow;
    } finally {
      timer.stop();

      if (await manifestFile.exists()) {
        await manifestFile.delete();
      }
      if (await overlayFile.exists()) {
        await overlayFile.delete();
      }
    }
  }

  Future<void> _writeOverlay(
    File file, {
    required int width,
    required int height,
    required String title,
    required String subject,
    required Duration duration,
    required WatermarkTemplate template,
    required WatermarkRotation rotation,
    required int videoDurationSeconds,
    required TimelapseOrientation orientation,
    DateTime? sessionStartTime,
    DateTime? sessionEndTime,
  }) async {
    final scale = width / 720.0;

    // Pour les templates animés, pour l'instant on utilise une seule image avec progression à 100%
    // L'animation complète nécessite une refonte de la pipeline FFmpeg
    await _writeSingleOverlay(
      file,
      width,
      height,
      scale,
      title,
      subject,
      duration,
      template,
      rotation,
      videoDurationSeconds,
      orientation,
      sessionStartTime,
      sessionEndTime,
      progress: 1.0,
      currentTime: duration,
    );
  }

  Future<void> _writeSingleOverlay(
    File file,
    int width,
    int height,
    double scale,
    String title,
    String subject,
    Duration duration,
    WatermarkTemplate template,
    WatermarkRotation rotation,
    int videoDurationSeconds,
    TimelapseOrientation orientation,
    DateTime? sessionStartTime,
    DateTime? sessionEndTime,
    {double progress = 1.0,
    Duration? currentTime}
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Appliquer la rotation selon le mode et la sélection
    _applyRotation(canvas, width, height, rotation, orientation);

    switch (template) {
      case WatermarkTemplate.none:
        // Pas de filigrane
        break;
      case WatermarkTemplate.stacked:
        _drawStackedOverlay(canvas, width, height, scale, title, subject, duration, rotation, videoDurationSeconds, sessionStartTime);
        break;
      case WatermarkTemplate.circle:
        _drawCircleOverlay(canvas, width, height, scale, title, subject, duration, rotation, videoDurationSeconds, sessionStartTime, progress: progress);
        break;
      case WatermarkTemplate.clock:
        _drawClockOverlay(canvas, width, height, scale, title, subject, duration, rotation, videoDurationSeconds, sessionStartTime, sessionEndTime, currentTime: currentTime ?? Duration.zero);
        break;
      case WatermarkTemplate.timer:
        _drawTimerOverlay(canvas, width, height, scale, title, subject, duration, rotation, videoDurationSeconds, sessionStartTime, currentTime: currentTime ?? Duration.zero);
        break;
      case WatermarkTemplate.progressbar:
        _drawProgressbarOverlay(canvas, width, height, scale, title, subject, duration, rotation, videoDurationSeconds, sessionStartTime, progress: progress);
        break;
    }

    final picture = recorder.endRecording();

    try {
      final image = await picture.toImage(width, height);

      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);

        if (data == null) {
          throw StateError('Création du filigrane impossible.');
        }

        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  void _drawStackedOverlay(
    Canvas canvas,
    int width,
    int height,
    double scale,
    String title,
    String subject,
    Duration duration,
    WatermarkRotation rotation,
    int videoDurationSeconds,
    DateTime? sessionStartTime,
  ) {
    final margin = 32.0 * scale;
    final barWidth = width - 2 * margin;
    double baseY = height - margin - 160.0 * scale;

    // Ajuster la position selon la rotation (pour mode portrait)
    if (rotation == WatermarkRotation.clockwise90) {
      baseY = height / 2.0 + 100.0 * scale;
    } else if (rotation == WatermarkRotation.counterclockwise90) {
      baseY = height / 2.0 + 100.0 * scale;
    } else if (rotation == WatermarkRotation.clockwise180) {
      baseY = margin + 100.0 * scale;
    }

    _drawClassicComposition(canvas, margin, barWidth, baseY, scale, title, subject, duration, videoDurationSeconds, sessionStartTime);
  }

  void _drawClassicComposition(
    Canvas canvas,
    double margin,
    double barWidth,
    double baseY,
    double scale,
    String title,
    String subject,
    Duration duration,
    int videoDurationSeconds,
    DateTime? sessionStartTime,
  ) {
    // Temps total en premier (au centre, très gros, format 00:00:00)
    final durationPainter = TextPainter(
      text: TextSpan(
        text: _formatDurationHHMMSS(duration),
        style: TextStyle(
          color: Colors.white,
          fontSize: 64.0 * scale,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: barWidth);

    durationPainter.paint(
      canvas,
      Offset(margin + (barWidth - durationPainter.width) / 2, baseY),
    );

    // Date et heure de début
    final dateTimeText = _formatDateTime(sessionStartTime);
    if (dateTimeText.isNotEmpty) {
      final dateTimePainter = TextPainter(
        text: TextSpan(
          text: dateTimeText,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16.0 * scale,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: barWidth);

      dateTimePainter.paint(
        canvas,
        Offset(margin + (barWidth - dateTimePainter.width) / 2, baseY + 75.0 * scale),
      );
    }

    // Matière avec ratio
    final subjectText = subject.isNotEmpty ? subject : 'Non spécifié';
    final ratio = _calculateRatio(duration, videoDurationSeconds);
    final subjectPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: subjectText,
            style: TextStyle(
              color: const Color(0xFF9B8AFF),
              fontSize: 24.0 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: '  x$ratio',
            style: TextStyle(
              color: const Color(0xFF67DCC0),
              fontSize: 24.0 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: barWidth);

    subjectPainter.paint(
      canvas,
      Offset(margin + (barWidth - subjectPainter.width) / 2, baseY + 100.0 * scale),
    );

    // Nom de l'app en dernier
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 18.0 * scale,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: barWidth);

    titlePainter.paint(
      canvas,
      Offset(margin + (barWidth - titlePainter.width) / 2, baseY + 130.0 * scale),
    );
  }

  int _calculateRatio(Duration duration, int videoDurationSeconds) {
    if (videoDurationSeconds <= 0) return 1;
    return (duration.inSeconds / videoDurationSeconds).ceil();
  }

  String _formatDateTime(DateTime? startTime) {
    if (startTime == null) return '';
    // Afficher la date et l'heure de début de session
    return '${startTime.day.toString().padLeft(2, '0')}/${startTime.month.toString().padLeft(2, '0')}  ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }

  void _applyRotation(
    Canvas canvas,
    int width,
    int height,
    WatermarkRotation rotation,
    TimelapseOrientation orientation,
  ) {
    final centerX = width / 2.0;
    final centerY = height / 2.0;

    // Rotation simple autour du centre pour tous les modes
    switch (rotation) {
      case WatermarkRotation.none:
        // Pas de rotation
        break;
      case WatermarkRotation.clockwise90:
        // Rotation 90° autour du centre
        canvas.translate(centerX, centerY);
        canvas.rotate(3.14159265359 / 2);
        canvas.translate(-centerX, -centerY);
        break;
      case WatermarkRotation.counterclockwise90:
        // Rotation -90° autour du centre
        canvas.translate(centerX, centerY);
        canvas.rotate(-3.14159265359 / 2);
        canvas.translate(-centerX, -centerY);
        break;
      case WatermarkRotation.clockwise180:
        // Rotation 180° autour du centre
        canvas.translate(centerX, centerY);
        canvas.rotate(3.14159265359);
        canvas.translate(-centerX, -centerY);
        break;
    }
  }

  void _drawCircleOverlay(
    Canvas canvas,
    int width,
    int height,
    double scale,
    String title,
    String subject,
    Duration duration,
    WatermarkRotation rotation,
    int videoDurationSeconds,
    DateTime? sessionStartTime,
    {double progress = 1.0}
  ) {
    final radius = 180.0 * scale;

    // Centrer le cercle avec ajustement selon rotation
    double centerX = width / 2;
    double centerY = height / 2;

    // Ajuster la position du cercle selon la rotation
    if (rotation == WatermarkRotation.clockwise90) {
      centerY = height / 2.0 - 60.0 * scale;
    } else if (rotation == WatermarkRotation.counterclockwise90) {
      centerY = height / 2.0 - 60.0 * scale;
    } else if (rotation == WatermarkRotation.clockwise180) {
      centerY = 32.0 * scale + radius;
    }

    // Cercle de progression animé (de 0 à progress)
    final progressPaint = Paint()
      ..color = const Color(0xFF9B8AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius - 15 * scale),
      -3.14159265359 / 2, // Commence en haut (-90°)
      6.28318530718 * progress, // Progression de 0 à 2*PI
      false,
      progressPaint,
    );

    // Composition classique à l'intérieur du cercle
    // Calculer la position pour que tout soit visible dans le cercle
    final barWidth = radius * 1.8; // Plus étroit pour tenir dans le cercle
    final baseY = centerY + 10.0 * scale; // Légèrement en dessous du centre du cercle

    _drawClassicComposition(canvas, centerX - barWidth / 2, barWidth, baseY, scale, title, subject, duration, videoDurationSeconds, sessionStartTime);
  }

  void _drawClockOverlay(
    Canvas canvas,
    int width,
    int height,
    double scale,
    String title,
    String subject,
    Duration duration,
    WatermarkRotation rotation,
    int videoDurationSeconds,
    DateTime? sessionStartTime,
    DateTime? sessionEndTime,
    {required Duration currentTime}
  ) {
    final margin = 32.0 * scale;
    final barWidth = width - 2 * margin;

    // Interpoler l'heure actuelle entre début et fin
    DateTime? displayTime;
    if (sessionStartTime != null && sessionEndTime != null) {
      final totalRecordingTime = sessionEndTime.difference(sessionStartTime);
      if (totalRecordingTime.inMicroseconds > 0) {
        final ratio = currentTime.inMicroseconds / duration.inMicroseconds;
        displayTime = sessionStartTime.add(totalRecordingTime * ratio);
      } else {
        displayTime = sessionStartTime;
      }
    } else {
      displayTime = DateTime.now();
    }

    // Horloge avec l'heure actuelle (au centre, très gros)
    final clockPainter = TextPainter(
      text: TextSpan(
        text: _formatClockTime(displayTime),
        style: TextStyle(
          color: Colors.white,
          fontSize: 72.0 * scale,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: barWidth);

    double clockY = height / 2 - 80.0 * scale;

    // Ajuster la position de l'horloge selon la rotation
    if (rotation == WatermarkRotation.clockwise90) {
      clockY = height / 2.0 - 150.0 * scale;
    } else if (rotation == WatermarkRotation.counterclockwise90) {
      clockY = height / 2.0 - 150.0 * scale;
    } else if (rotation == WatermarkRotation.clockwise180) {
      clockY = margin + 80.0 * scale; // Plus haut pour laisser de l'espace
    }

    clockPainter.paint(
      canvas,
      Offset(margin + (barWidth - clockPainter.width) / 2, clockY),
    );

    // Composition classique en bas avec ajustement de rotation
    double baseY = height - margin - 160.0 * scale;

    // Ajuster la position selon la rotation (pour mode portrait)
    if (rotation == WatermarkRotation.clockwise90) {
      baseY = height / 2.0 + 100.0 * scale;
    } else if (rotation == WatermarkRotation.counterclockwise90) {
      baseY = height / 2.0 + 100.0 * scale;
    } else if (rotation == WatermarkRotation.clockwise180) {
      baseY = margin + 250.0 * scale; // Plus bas pour laisser de l'espace avec l'horloge
    }

    _drawClassicComposition(canvas, margin, barWidth, baseY, scale, title, subject, duration, videoDurationSeconds, sessionStartTime);
  }

  void _drawTimerOverlay(
    Canvas canvas,
    int width,
    int height,
    double scale,
    String title,
    String subject,
    Duration duration,
    WatermarkRotation rotation,
    int videoDurationSeconds,
    DateTime? sessionStartTime,
    {required Duration currentTime}
  ) {
    final margin = 32.0 * scale;
    final barWidth = width - 2 * margin;

    // Chronomètre avec le temps écoulé (au centre, très gros, format 00:00:00)
    final timerPainter = TextPainter(
      text: TextSpan(
        text: _formatDurationHHMMSS(currentTime),
        style: TextStyle(
          color: Colors.white,
          fontSize: 72.0 * scale,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: barWidth);

    double timerY = height / 2 - 80.0 * scale;

    // Ajuster la position du chronomètre selon la rotation
    if (rotation == WatermarkRotation.clockwise90) {
      timerY = height / 2.0 - 150.0 * scale;
    } else if (rotation == WatermarkRotation.counterclockwise90) {
      timerY = height / 2.0 - 150.0 * scale;
    } else if (rotation == WatermarkRotation.clockwise180) {
      timerY = margin + 80.0 * scale; // Plus haut pour laisser de l'espace
    }

    timerPainter.paint(
      canvas,
      Offset(margin + (barWidth - timerPainter.width) / 2, timerY),
    );

    // Composition classique en bas avec ajustement de rotation
    double baseY = height - margin - 160.0 * scale;

    // Ajuster la position selon la rotation (pour mode portrait)
    if (rotation == WatermarkRotation.clockwise90) {
      baseY = height / 2.0 + 100.0 * scale;
    } else if (rotation == WatermarkRotation.counterclockwise90) {
      baseY = height / 2.0 + 100.0 * scale;
    } else if (rotation == WatermarkRotation.clockwise180) {
      baseY = margin + 250.0 * scale; // Plus bas pour laisser de l'espace avec le chronomètre
    }

    _drawClassicComposition(canvas, margin, barWidth, baseY, scale, title, subject, duration, videoDurationSeconds, sessionStartTime);
  }

  void _drawProgressbarOverlay(
    Canvas canvas,
    int width,
    int height,
    double scale,
    String title,
    String subject,
    Duration duration,
    WatermarkRotation rotation,
    int videoDurationSeconds,
    DateTime? sessionStartTime,
    {double progress = 1.0}
  ) {
    final margin = 32.0 * scale;
    final barWidth = width - 2 * margin;
    final barHeight = 16.0 * scale;
    double barY = height - barHeight - margin - 170.0 * scale;

    // Ajuster la position de la barre selon la rotation
    if (rotation == WatermarkRotation.clockwise90) {
      barY = height / 2.0 - 60.0 * scale;
    } else if (rotation == WatermarkRotation.counterclockwise90) {
      barY = height / 2.0 - 60.0 * scale;
    } else if (rotation == WatermarkRotation.clockwise180) {
      barY = margin + 60.0 * scale;
    }

    // Barre de fond
    final bgPaint = Paint()
      ..color = const Color(0xFF252630)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(margin, barY, barWidth, barHeight),
        Radius.circular(8.0 * scale),
      ),
      bgPaint,
    );

    // Barre de progression
    final progressPaint = Paint()
      ..color = const Color(0xFF9B8AFF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(margin, barY, barWidth * progress, barHeight),
        Radius.circular(8.0 * scale),
      ),
      progressPaint,
    );

    // Composition classique en dessous de la barre avec ajustement de rotation
    double baseY = height - margin - 160.0 * scale;

    // Ajuster la position selon la rotation (pour mode portrait)
    if (rotation == WatermarkRotation.clockwise90) {
      baseY = height / 2.0 + 100.0 * scale;
    } else if (rotation == WatermarkRotation.counterclockwise90) {
      baseY = height / 2.0 + 100.0 * scale;
    } else if (rotation == WatermarkRotation.clockwise180) {
      baseY = margin + 100.0 * scale;
    }

    _drawClassicComposition(canvas, margin, barWidth, baseY, scale, title, subject, duration, videoDurationSeconds, sessionStartTime);
  }

  String _formatDurationHHMMSS(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatClockTime(DateTime time) {
    final hours = time.hour;
    final minutes = time.minute;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Future<void> deleteCaptureDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  List<String> _buildOutputFrames({
    required List<String> imagePaths,
    required List<Duration>? elapsedTimes,
    required Duration? sessionDuration,
    required int totalFrames,
  }) {
    if (imagePaths.length == 1) {
      return List<String>.filled(totalFrames, imagePaths.first);
    }

    final duration =
        sessionDuration ??
        (elapsedTimes != null && elapsedTimes.isNotEmpty
            ? elapsedTimes.last
            : Duration.zero);

    if (elapsedTimes == null || duration <= Duration.zero) {
      return List.generate(totalFrames, (i) {
        final index = (i * (imagePaths.length - 1) / (totalFrames - 1)).round();
        return imagePaths[index];
      });
    }

    final result = <String>[];
    var sourceIndex = 0;

    for (var i = 0; i < totalFrames; i++) {
      final target = (duration.inMicroseconds * i / (totalFrames - 1)).round();

      while (sourceIndex < elapsedTimes.length - 1) {
        final current = (elapsedTimes[sourceIndex].inMicroseconds - target)
            .abs();
        final next = (elapsedTimes[sourceIndex + 1].inMicroseconds - target)
            .abs();

        if (next >= current) break;
        sourceIndex++;
      }

      result.add(imagePaths[sourceIndex]);
    }

    return result;
  }

  String _escapePath(String path) =>
      path.replaceAll('\\', '/').replaceAll("'", r"'\''");

  String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
