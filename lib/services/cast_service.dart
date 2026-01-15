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

  CastDevice? _connectedDevice;
  String get connectedDeviceName => _connectedDevice?.name ?? 'Chromecast';

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

  double _currentPosition = 0;
  DateTime? _lastUpdateTime;

  double get position {
    if (_lastUpdateTime == null) return _currentPosition;
    if (_isPlaying) {
      final elapsed = DateTime.now().difference(_lastUpdateTime!).inSeconds;
      return _currentPosition + elapsed;
    }
    return _currentPosition;
  }

  Future<void> connect(CastDevice device) async {
    try {
      final session = await CastSessionManager().startSession(device);
      _session = session;
      _connectedDevice = device;

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
            print("Received MEDIA_STATUS: $status");

            if (status is Map) {
              // Extract state for validation
              String? state;
              if (status.containsKey('playerState')) {
                state = status['playerState'];
                _isPlaying = state == 'PLAYING' || state == 'BUFFERING';
                print("Updated playerState: $state (Playing: $_isPlaying)");
              }

              // Only update mediaSessionId if we are in an ACTIVE state (Playing/Buffering)
              // If IDLE, the ID is likely from the old session that is ending, so we ignore it.
              if (status.containsKey('mediaSessionId') && state != 'IDLE') {
                final int? newSessionId = status['mediaSessionId'];
                if (newSessionId != null && newSessionId != _mediaSessionId) {
                  print(
                    "New Active Media Session ID detected: $newSessionId (Old: $_mediaSessionId)",
                  );
                  _mediaSessionId = newSessionId;
                }
              }

              if (state == 'IDLE') {
                // Do not clear. Just stop playing.
                _isPlaying = false;
              }

              if (status.containsKey('currentTime')) {
                _currentPosition = (status['currentTime'] as num).toDouble();
                _lastUpdateTime = DateTime.now();
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

  Future<void> seek(double positionInSeconds) async {
    if (_session == null) {
      print("Seek failed: Session is null");
      return;
    }

    // Proper strict check: Do NOT guess. If we don't have a session ID, we can't seek.
    if (_mediaSessionId == null) {
      print("Seek failed: mediaSessionId is null. Wait for media to load.");
      return;
    }

    if (_mediaSessionId == null) {
      print("Seek failed: mediaSessionId is still null after check");
      return;
    }

    // Simplified SEEK message to avoid conflict
    final message = {
      'type': 'SEEK',
      'mediaSessionId': _mediaSessionId,
      'currentTime': positionInSeconds,
      'requestId': DateTime.now().millisecondsSinceEpoch,
    };

    print("Sending SEEK message: $message");

    _session!.sendMessage('urn:x-cast:com.google.cast.media', message);
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
      _connectedDevice = null;
      _mediaSessionId = null;
      _isPlaying = false;
      _currentPosition = 0;
      _lastUpdateTime = null;
      notifyListeners();
    }
  }

  Future<void> loadMedia(
    String url, {
    String? title,
    String? imageUrl,
    double? startTime,
  }) async {
    if (_session == null) return;

    // Robust MIME type detection
    String contentType = 'video/mp4';
    if (url.contains('.m3u8')) {
      contentType = 'application/vnd.apple.mpegurl'; // HLS standard for Cast
    } else if (url.contains('.ts')) {
      contentType = 'video/mp2t'; // MPEG-TS
    } else if (url.contains('.mpd')) {
      contentType = 'application/dash+xml';
    } else if (url.contains('.webm')) {
      contentType = 'video/webm';
    } else if (url.contains('.mkv')) {
      contentType = 'video/webm';
    }

    print(
      "Starting cast media load for $url at ${startTime ?? 0} with type $contentType",
    );
    // Stop previous session if active to prevent state conflicts
    // Stop previous session if active to prevent state conflicts
    if (_mediaSessionId != null) {
      try {
        print("Stopping previous media session: $_mediaSessionId");
        _session!.sendMessage('urn:x-cast:com.google.cast.media', {
          'type': 'STOP',
          'mediaSessionId': _mediaSessionId,
          'requestId': DateTime.now().millisecondsSinceEpoch,
        });
        // Do not wait - fire and forget to avoid blocking
      } catch (e) {
        print("Error stopping previous media: $e");
      }
    }

    // Clear previous session ID immediately
    _mediaSessionId = null;
    _isPlaying = false;
    _currentPosition = 0; // Reset position display

    try {
      final message = {
        'type': 'LOAD',
        'autoPlay': true,
        'currentTime': startTime ?? 0,
        'media': {
          'contentId': url,
          'contentType': contentType,
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

      // Force a status update check soon after load
      await Future.delayed(const Duration(seconds: 1));
      _session!.sendMessage('urn:x-cast:com.google.cast.media', {
        'type': 'GET_STATUS',
        'requestId': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, stack) {
      print("Error loading media: $e\n$stack");
    }
  }
}
