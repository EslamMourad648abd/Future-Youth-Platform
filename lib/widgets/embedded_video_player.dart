import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/brand_colors.dart';

class EmbeddedVideoPlayer extends StatefulWidget {
  final String? courseId;
  final String? videoId;
  final String? driveUrl;
  final String? videoUrl;
  final String? storagePath;
  final String lessonTitle;

  const EmbeddedVideoPlayer({
    super.key,
    this.courseId,
    this.videoId,
    this.driveUrl,
    this.videoUrl,
    this.storagePath,
    required this.lessonTitle,
  });

  @override
  State<EmbeddedVideoPlayer> createState() => _EmbeddedVideoPlayerState();
}

class _EmbeddedVideoPlayerState extends State<EmbeddedVideoPlayer> {
  bool loading = true;
  String? resolvedVideoUrl;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _resolveVideoSource();
  }

  Future<void> _resolveVideoSource() async {
    // 1. Try calling getPreviewVideoUrl callable if courseId and videoId are present
    if (widget.courseId != null && widget.videoId != null) {
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('getPreviewVideoUrl');
        final result = await callable({'courseId': widget.courseId, 'videoId': widget.videoId});
        final data = Map<String, dynamic>.from(result.data as Map);
        if (data['ok'] == true && data['videoUrl'] != null) {
          if (mounted) {
            setState(() {
              resolvedVideoUrl = data['videoUrl'].toString();
              loading = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint("getPreviewVideoUrl callable error: $e");
      }
    }

    // 2. Try resolving Firebase Storage download URL
    if (widget.storagePath != null && widget.storagePath!.isNotEmpty) {
      try {
        final url = await FirebaseStorage.instance
            .ref(widget.storagePath)
            .getDownloadURL();
        if (mounted) {
          setState(() {
            resolvedVideoUrl = url;
            loading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint("Firebase Storage download URL error: $e");
      }
    }

    // 3. Fallback to Drive URL or direct Video URL
    final rawUrl = widget.driveUrl ?? widget.videoUrl;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      var cleanUrl = rawUrl.trim();
      if (cleanUrl.contains('/file/d/')) {
        final fileId = cleanUrl.split('/file/d/').last.split('/').first;
        cleanUrl = 'https://drive.google.com/file/d/$fileId/preview';
      }
      if (mounted) {
        setState(() {
          resolvedVideoUrl = cleanUrl;
          loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        errorMessage = 'No video URL or storage path provided for this lesson.';
        loading = false;
      });
    }
  }

  Future<void> _openExternalVideo() async {
    final target = resolvedVideoUrl ?? widget.driveUrl ?? widget.videoUrl;
    if (target != null && target.isNotEmpty) {
      final uri = Uri.parse(target);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Resolving video stream...', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BrandColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.error),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: BrandColors.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: BrandColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      color: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill, color: BrandColors.green, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      widget.lessonTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ready for Video Review',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.video_camera_back_outlined, color: BrandColors.navy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resolvedVideoUrl ?? 'Video source linked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _openExternalVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Play / Open Stream', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
