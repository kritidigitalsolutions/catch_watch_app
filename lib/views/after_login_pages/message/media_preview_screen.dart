import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../utils/share_helper.dart';

class MediaPreviewScreen extends StatefulWidget {
  final String url;
  final String type; // 'image' or 'video'

  const MediaPreviewScreen({super.key, required this.url, required this.type});

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  bool _isDownloading = false;
  bool _isInitializing = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _isInitializing = true;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final previous = _videoController;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _videoController!.initialize();
      await previous?.dispose();
      await _videoController!.setLooping(true);
      await _videoController!.play();
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error initializing media preview: $e');
      await _videoController?.dispose();
      _videoController = null;
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _hasError = true;
      });
    }
  }

  Future<void> _retryVideo() async {
    if (_isInitializing) return;
    setState(() {
      _isInitializing = true;
      _hasError = false;
    });
    await _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _saveMedia() async {
    if (_isDownloading) return;

    try {
      // Check photo library permission before proceeding
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        // Request access when user taps save
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Photo library permission is required to save photos and videos."),
              ),
            );
          }
          return;
        }
      }

      setState(() => _isDownloading = true);

      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final extension = widget.type == 'video' ? 'mp4' : 'jpg';
      final path = "${tempDir.path}/temp_media_${DateTime.now().millisecondsSinceEpoch}.$extension";

      await dio.download(widget.url, path);

      if (widget.type == 'video') {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }

      // Clean up temporary downloaded file
      final tempFile = File(path);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved to gallery")),
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        final message = switch (e.type) {
          GalExceptionType.accessDenied =>
            "Permission to access the photo library was denied.",
          GalExceptionType.notEnoughSpace =>
            "Not enough storage space available to save media.",
          GalExceptionType.notSupportedFormat =>
            "The media format is not supported.",
          GalExceptionType.unexpected =>
            "Failed to save media to the photo library.",
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save media. Please try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareMedia() async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final extension = widget.type == 'video' ? 'mp4' : 'jpg';
      final path = "${tempDir.path}/share_media.$extension";

      await dio.download(widget.url, path);
      if (!mounted) return;
      await ShareHelper.shareFile(
        path: path,
        context: context,
      );
    } catch (e) {
      debugPrint("Error sharing: $e");
    }
  }

  Widget _buildVideoBody() {
    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 56),
            const SizedBox(height: 12),
            const Text(
              "Unable to play this video. Please try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _retryVideo,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.refresh, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    "Retry",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final ctrl = _videoController;
    if (_isInitializing || ctrl == null || !ctrl.value.isInitialized) {
      return const CircularProgressIndicator();
    }

    return AspectRatio(
      aspectRatio: ctrl.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(ctrl),
          GestureDetector(
            onTap: () {
              setState(() {
                ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
              });
            },
            child: Icon(
              ctrl.value.isPlaying
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              size: 60,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isDownloading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _saveMedia,
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareMedia,
          ),
        ],
      ),
      body: Center(
        child: widget.type == 'video'
            ? _buildVideoBody()
            : InteractiveViewer(
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
      ),
    );
  }
}
