import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class GoogleDrivePlayer extends StatefulWidget {
  final String videoUrl;

  const GoogleDrivePlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<GoogleDrivePlayer> createState() =>
      _GoogleDrivePlayerState();
}

class _GoogleDrivePlayerState
    extends State<GoogleDrivePlayer> {

  late final String _viewType;

  @override
  void initState() {
    super.initState();

    _viewType =
    'google-drive-player-${identityHashCode(this)}';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
          (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.position = 'relative'
          ..style.backgroundColor = '#000'
          ..style.overflow = 'hidden';

        // -------------------------------------------------------
        // GOOGLE DRIVE IFRAME
        // -------------------------------------------------------

        final iframe = html.IFrameElement()
          ..src = _normalizeDriveUrl(widget.videoUrl)
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = '0'
          ..style.display = 'block'
          ..allowFullscreen = true
          ..setAttribute(
            'allow',
            'autoplay; fullscreen; encrypted-media',
          );

        // -------------------------------------------------------
        // WATERMARK
        // -------------------------------------------------------

        final watermark = html.DivElement()
          ..text = 'Powered By : Eng. Eslam Mourad'
          ..style.position = 'absolute'
          ..style.right = '18px'
          ..style.bottom = '14px'
          ..style.padding = '6px 10px'
          ..style.backgroundColor =
              'rgba(255,255,255,0.75)'
          ..style.color = '#003366'
          ..style.fontSize = '13px'
          ..style.fontFamily =
              'Arial, sans-serif'
          ..style.fontWeight = '600'
          ..style.borderRadius = '6px'
          ..style.pointerEvents = 'none'
          ..style.zIndex = '10'
          ..style.userSelect = 'none'
          ..style.whiteSpace = 'nowrap';

        container.children.add(iframe);
        container.children.add(watermark);

        return container;
      },
    );
  }

  // ============================================================
  // NORMALIZE GOOGLE DRIVE URL
  // ============================================================

  String _normalizeDriveUrl(String url) {
    final trimmed = url.trim();

    if (trimmed.isEmpty) {
      return trimmed;
    }

    // Already a Google Drive preview URL.
    if (trimmed.contains('/preview')) {
      return trimmed;
    }

    // Convert:
    //
    // https://drive.google.com/file/d/FILE_ID/view
    //
    // to:
    //
    // https://drive.google.com/file/d/FILE_ID/preview

    final match = RegExp(
      r'drive\.google\.com/file/d/([^/]+)',
    ).firstMatch(trimmed);

    if (match != null) {
      final fileId = match.group(1);

      return 'https://drive.google.com/file/d/$fileId/preview';
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(16),
        child: HtmlElementView(
          viewType: _viewType,
        ),
      ),
    );
  }
}