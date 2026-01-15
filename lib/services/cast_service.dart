import 'dart:async';
import 'package:cast_plus/cast.dart';
import 'package:flutter/foundation.dart';

class CastService extends ChangeNotifier {
  static final CastService _instance = CastService._internal();
  factory CastService() => _instance;
  CastService._internal();

  List<CastDevice> _devices = [];
  List<CastDevice> get devices => _devices;

  CastSession? _session;
  bool get isConnected => _session != null;

  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;

  CastDiscoveryService? _discoveryService;

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _devices = [];

    try {
      _discoveryService = CastDiscoveryService();
      final devices = await _discoveryService!.search();
      _devices = devices;
      notifyListeners();
    } catch (e) {
      debugPrint("Cast Discovery Error: $e");
    }
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    notifyListeners();
  }

  int? _mediaSessionId;
  int? get mediaSessionId => _mediaSessionId;

  // Track playback state for UI updates
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Future<void> connect(CastDevice device) async {
    try {
      final session = await CastSessionManager().startSession(device);
      _session = session;

      // Reset state
      _mediaSessionId = null;
      _isPlaying = false;
      notifyListeners();

      _session!.messageStream.listen((msg) {
        // Parse MEDIA_STATUS to get mediaSessionId
        if (msg.containsKey('type') && msg['type'] == 'MEDIA_STATUS') {
          if (msg.containsKey('status') &&
              msg['status'] is List &&
              (msg['status'] as List).isNotEmpty) {
            final status = (msg['status'] as List).first;
            if (status is Map) {
              if (status.containsKey('mediaSessionId')) {
                _mediaSessionId = status['mediaSessionId'];
              }
              if (status.containsKey('playerState')) {
                _isPlaying = status['playerState'] == 'PLAYING';
              }
              notifyListeners();
            }
          }
        }
      });

      // Launch Default Media Receiver
      _session!.sendMessage(CastSession.kNamespaceReceiver, {
        'type': 'LAUNCH',
        'appId': 'CC1AD845',
      });

      // Delay to ensure launch
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint("Cast Connection Error: $e");
      _session = null;
      notifyListeners();
    }
  }

  void play() {
    if (_session == null || _mediaSessionId == null) return;
    _session!.sendMessage('urn:x-cast:com.google.cast.media', {
      'type': 'PLAY',
      'mediaSessionId': _mediaSessionId,
      'requestId': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void pause() {
    if (_session == null || _mediaSessionId == null) return;
    _session!.sendMessage('urn:x-cast:com.google.cast.media', {
      'type': 'PAUSE',
      'mediaSessionId': _mediaSessionId,
      'requestId': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void seek(double positionInSeconds) {
    if (_session == null || _mediaSessionId == null) return;
    _session!.sendMessage('urn:x-cast:com.google.cast.media', {
      'type': 'SEEK',
      'mediaSessionId': _mediaSessionId,
      'currentTime': positionInSeconds,
      'requestId': DateTime.now().millisecondsSinceEpoch,
      'resumeState': 'PLAYBACK_START', // Auto-resume
    });
  }

  void playOrPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  Future<void> disconnect() async {
    if (_session != null) {
      try {
        _session!.close();
      } catch (e) {
        debugPrint("Error disconnecting: $e");
      }
      _session = null;
      _mediaSessionId = null;
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> loadMedia(String url, {String? title, String? imageUrl}) async {
    if (_session == null) return;

    print("Starting cast media load for $url");
    try {
      final message = {
        'type': 'LOAD',
        'autoPlay': true,
        'currentTime': 0,
        'media': {
          'contentId': url,
          'contentType': 'video/mp4',
          'streamType': 'BUFFERED',
          'metadata': {
            'metadataType': 0, // Generic
            'title': title ?? 'Video',
            'images': [
              if (imageUrl != null) {'url': imageUrl},
            ],
          },
        },
      };

      _session!.sendMessage('urn:x-cast:com.google.cast.media', message);
      print("Cast LOAD message sent");
    } catch (e, stack) {
      print("Error loading media: $e\n$stack");
    }
  }
}
