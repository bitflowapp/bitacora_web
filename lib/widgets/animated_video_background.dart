// lib/widgets/animated_video_background.dart
//
// Fondo animado con video 3D renderizado en Blender.
// Envuelve tu Scaffold principal y mantiene todo el diseño actual.

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AnimatedVideoBackground extends StatefulWidget {
  final Widget child;

  const AnimatedVideoBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedVideoBackground> createState() =>
      _AnimatedVideoBackgroundState();
}

class _AnimatedVideoBackgroundState extends State<AnimatedVideoBackground> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/video/gridnote_cells_loop.mp4',
    );
    _initFuture = _init();
  }

  Future<void> _init() async {
    await _controller.initialize();
    if (!mounted) return;
    await _controller.setLooping(true);
    await _controller.setVolume(0); // mudo => autoplay en Web sin problemas
    await _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Video de fondo
        Positioned.fill(
          child: FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }

              final value = _controller.value;
              if (!value.isInitialized) {
                return const SizedBox.shrink();
              }

              final videoSize = value.size;
              // Fallback si el size viene en 0 (típico en Web)
              final screenSize = MediaQuery.of(context).size;
              final width =
              videoSize.width == 0 ? screenSize.width : videoSize.width;
              final height =
              videoSize.height == 0 ? screenSize.height : videoSize.height;

              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: VideoPlayer(_controller),
                ),
              );
            },
          ),
        ),

        // Capa oscura para que la UI se lea bien encima del video
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.75),
          ),
        ),

        // Contenido actual de la app
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }
}