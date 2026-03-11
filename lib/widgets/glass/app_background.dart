import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AppBackground extends StatefulWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.asset('assets/videos/background_video.mp4')
          ..initialize().then((_) {
            _controller.setLooping(true);
            _controller.setVolume(0.0); // Mute the video
            _controller.play();
            if (mounted) {
              setState(() {
                _initialized = true;
              });
            }
          }).catchError((error) {
            debugPrint("Error initializing video: $error");
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E1B4B), // Indigo 950
                  Color(0xFF312E81), // Indigo 900
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3F4F6), // Gray 100
                  Color(0xFFE0E7FF), // Indigo 100
                  Color(0xFFC7D2FE), // Indigo 200
                ],
              ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer
          if (_initialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),

          // Overlay for readability
          Container(
            color:
                (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3),
          ),

          // Ambient blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.purple : Colors.blue)
                    .withValues(alpha: 0.2),
                // filter: null, // Add blur here if needed, but easier to do with backdrop filter
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.blue : Colors.purple)
                    .withValues(alpha: 0.15),
              ),
            ),
          ),
          // Main content
          SafeArea(child: widget.child),
        ],
      ),
    );
  }
}
