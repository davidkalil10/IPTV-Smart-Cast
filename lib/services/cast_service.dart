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

  Future<void> connect(CastDevice device) async {
    try {
      final session = await CastSessionManager().startSession(device);
      _session = session;
      notifyListeners();

      _session!.messageStream.listen((msg) {
        // Handle messages if needed
      });
    } catch (e) {
      debugPrint("Cast Connection Error: $e");
      _session = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_session != null) {
      // _session!.close();
      _session = null;
      notifyListeners();
    }
  }

  Future<void> loadMedia(String url, {String? title, String? imageUrl}) async {
    if (_session == null) return;

    /*
    final media = CastMedia(
      contentId: url,
      contentType: 'video/mp4',
      metadata: CastMediaMetadata(
        title: title ?? 'Video',
        images: imageUrl != null
            ? [CastMediaImage(url: Uri.parse(imageUrl))]
            : [],
      ),
    );

    _session!.sendMessage(
      CastSessionPlayMessage(session: _session!, media: media),
    );
    */
    debugPrint("TODO: Implement loadMedia with correct API");
  }

  void play() {
    // Logic for play
  }

  void pause() {
    // Logic for pause
  }
}
