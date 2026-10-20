import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'white_matte_video_filter.dart';

class HomeGreetingVideo extends StatefulWidget {
  const HomeGreetingVideo({super.key});

  @override
  State<HomeGreetingVideo> createState() => _HomeGreetingVideoState();
}

class _HomeGreetingVideoState extends State<HomeGreetingVideo> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _initializationStarted = false;
  bool? _tickerEnabled;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/dia.mp4');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled == tickerEnabled) return;
    _tickerEnabled = tickerEnabled;
    if (tickerEnabled && !_initializationStarted) {
      _initializationStarted = true;
      _initialize();
    } else if (_initialized) {
      if (tickerEnabled) {
        unawaited(_controller.play());
      } else {
        unawaited(_controller.pause());
      }
    }
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) setState(() => _initialized = true);
    } catch (error, stackTrace) {
      debugPrint('Unable to play the home greeting video: $error\n$stackTrace');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox(width: 58, height: 54);
    return SizedBox(
      width: 58,
      height: 54,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColorFiltered(
              colorFilter: whiteMatteVideoFilter,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
