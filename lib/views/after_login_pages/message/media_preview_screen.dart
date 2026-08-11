import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          setState(() {});
          _videoController?.play();
          _videoController?.setLooping(true);
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _saveMedia() async {
    setState(() => _isDownloading = true);
    try {
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved to gallery")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e")),
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
          await Share.shareXFiles([XFile(path)]);
      } catch (e) {
          debugPrint("Error sharing: $e");
      }
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
            ? (_videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_videoController!),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _videoController!.value.isPlaying
                                  ? _videoController!.pause()
                                  : _videoController!.play();
                            });
                          },
                          child: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 60,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator())
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
