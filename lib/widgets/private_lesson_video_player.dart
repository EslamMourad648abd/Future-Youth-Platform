import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/localization_service.dart';

/// Plays a short-lived server-issued private media URL. The URL is never stored
/// in Firestore and is expected to expire after a few minutes.
class PrivateLessonVideoPlayer extends StatefulWidget {
  final String url;
  final Future<void> Function()? onCompleted;
  final Future<void> Function(int positionSeconds, bool isPlaying)? onProgress;

  const PrivateLessonVideoPlayer({
    super.key,
    required this.url,
    this.onCompleted,
    this.onProgress,
  });

  @override
  State<PrivateLessonVideoPlayer> createState() => _PrivateLessonVideoPlayerState();
}

class _PrivateLessonVideoPlayerState extends State<PrivateLessonVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  Object? _error;
  Duration _lastPosition = Duration.zero;
  int _watchedMilliseconds = 0;
  bool _completionNotified = false;
  Timer? _progressTimer;
  bool _progressReportInFlight = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.addListener(_onControllerChanged);
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _reportProgress());
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _reportProgress() async {
    final callback = widget.onProgress;
    if (!mounted || !_ready || callback == null || _progressReportInFlight) return;
    _progressReportInFlight = true;
    try {
      await callback(_controller.value.position.inSeconds, _controller.value.isPlaying);
    } catch (error) {
      debugPrint('Playback progress report failed: $error');
    } finally {
      _progressReportInFlight = false;
    }
  }

  void _onControllerChanged() {
    if (!mounted || !_ready) return;
    final value = _controller.value;
    final position = value.position;
    final delta = position - _lastPosition;
    // Count forward playback only; a seek jump is not treated as watched time.
    if (value.isPlaying && delta.inMilliseconds > 0 && delta.inMilliseconds <= 2000) {
      _watchedMilliseconds += delta.inMilliseconds;
    }
    _lastPosition = position;

    final durationMs = value.duration.inMilliseconds;
    if (!_completionNotified &&
        durationMs > 0 &&
        _watchedMilliseconds >= durationMs * 0.9 &&
        widget.onCompleted != null) {
      _completionNotified = true;
      unawaited(widget.onCompleted!.call());
    }
    setState(() {});
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  String _duration(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes >= 60) {
      return '${duration.inHours}:${two(minutes % 60)}:${two(seconds)}';
    }
    return '${two(minutes)}:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_error != null) {
      return Center(
        child: Text(
          fypTranslate(context, 'video_playback_failed', 'Could not load this video. Reopen the lesson to request a fresh playback link.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurface),
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }

    final value = _controller.value;
    final duration = value.duration;
    final position = value.position;
    final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final currentMs = position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
            ColoredBox(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: fypTranslate(context, value.isPlaying ? 'pause_video' : 'play_video', value.isPlaying ? 'Pause video' : 'Play video'),
                      onPressed: () {
                        setState(() {
                          value.isPlaying ? _controller.pause() : _controller.play();
                        });
                      },
                      color: Colors.white,
                      icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    Text(
                      '${_duration(position)} / ${_duration(duration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: currentMs,
                        max: maxMs,
                        onChanged: (next) => _controller.seekTo(Duration(milliseconds: next.round())),
                        activeColor: scheme.secondary,
                        inactiveColor: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
