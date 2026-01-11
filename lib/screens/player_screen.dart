import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import '../models/channel.dart';
import '../widgets/video_controls_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  bool _isError = false;
  String _errorMessage = '';
  double? _overrideAspectRatio;
  BoxFit _overrideFit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    // Force landscape for player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.channel.streamUrl),
        // Use default options, mixWithOthers is good for audio focus but strictly not required for basic play
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _videoPlayerController!.initialize();
      _videoPlayerController!.play();
      setState(() {});
    } catch (e) {
      debugPrint("Error initializing player: $e");
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    // Restore orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _onNextEpisode() {
    // Placeholder for Next Episode logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Próximo episódio não disponível neste contexto."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              const Text(
                'Erro ao reproduzir vídeo',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
              ),
              SizedBox(height: 16),
              Text(
                'Carregando transmissão...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Video Layer
          Center(
            child: AspectRatio(
              aspectRatio:
                  _overrideAspectRatio ??
                  _videoPlayerController!.value.aspectRatio,
              child: FittedBox(
                fit: _overrideFit,
                child: SizedBox(
                  width: _videoPlayerController!.value.size.width,
                  height: _videoPlayerController!.value.size.height,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            ),
          ),

          // Controls Layer
          VideoControlsOverlay(
            controller: _videoPlayerController!,
            channel: widget.channel,
            onNextEpisode: _onNextEpisode,
            onResize: (ratio, fit) {
              setState(() {
                _overrideAspectRatio = ratio > 0
                    ? ratio
                    : null; // If 0 or negative passed (e.g. for Fit Parent), might interpret as null or auto
                _overrideFit = fit;
              });
            },
          ),
        ],
      ),
    );
  }
}
