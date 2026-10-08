import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:iconsax/iconsax.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? networkUrl;
  final String? filePath;
  final bool autoPlay;
  final bool showControls;

  const VideoPlayerWidget({
    super.key,
    this.networkUrl,
    this.filePath,
    this.autoPlay = false,
    this.showControls = true,
  }) : assert(networkUrl != null || filePath != null, 'Either networkUrl or filePath must be provided');

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    try {
      if (widget.networkUrl != null) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.networkUrl!));
      } else if (widget.filePath != null) {
        _controller = VideoPlayerController.file(File(widget.filePath!));
      }

      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        if (widget.autoPlay) {
          _controller!.play();
          setState(() {
            _isPlaying = true;
          });
        }

        _controller!.addListener(() {
          if (mounted) {
            final isPlaying = _controller!.value.isPlaying;
            if (_isPlaying != isPlaying) {
              setState(() {
                _isPlaying = isPlaying;
              });
            }
          }
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.showControls ? _showControlsTemporarily : _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),

            // Play/Pause overlay
            if (!_isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(20),
                child: const Icon(
                  Iconsax.play,
                  color: Colors.white,
                  size: 50,
                ),
              ),

            // Controls
            if (widget.showControls && _showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.grey,
                          backgroundColor: Colors.white.withOpacity(0.26),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Controls row
                      Row(
                        children: [
                          // Play/Pause button
                          IconButton(
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              _isPlaying ? Iconsax.pause : Iconsax.play,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // Time display
                          ValueListenableBuilder(
                            valueListenable: _controller!,
                            builder: (context, VideoPlayerValue value, child) {
                              return Text(
                                '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                          
                          const Spacer(),
                          
                          // Fullscreen button (optional)
                          IconButton(
                            onPressed: () {
                              // Implement fullscreen if needed
                            },
                            icon: const Icon(
                              Iconsax.maximize_4,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
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
