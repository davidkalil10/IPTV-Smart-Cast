import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackService {
  static final PlaybackService _instance = PlaybackService._internal();
  factory PlaybackService() => _instance;
  PlaybackService._internal();

  static const String _storageKey = 'playback_progress';

  // Map<ContentID, PositionInSeconds>
  Map<String, int> _progressMap = {};

  // Map<SeriesID, LastEpisodeID>
  Map<String, String> _seriesProgressMap = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Content Progress
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(jsonString);
        _progressMap = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        print('Error parsing playback progress: $e');
      }
    }

    // Load Series Progress
    final String? seriesJsonString = prefs.getString('${_storageKey}_series');
    if (seriesJsonString != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(seriesJsonString);
        _seriesProgressMap = decoded.map(
          (key, value) => MapEntry(key, value as String),
        );
      } catch (e) {
        print('Error parsing series progress: $e');
      }
    }
  }

  int getProgress(String contentId) {
    return _progressMap[contentId] ?? 0;
  }

  String? getLastEpisodeId(String seriesId) {
    return _seriesProgressMap[seriesId];
  }

  Future<void> saveProgress(
    String contentId,
    int positionSeconds,
    int durationSeconds, {
    String? seriesId,
  }) async {
    // If watched > 95%, consider finished and remove
    if (durationSeconds > 0 && positionSeconds > (durationSeconds * 0.95)) {
      await removeProgress(contentId, seriesId: seriesId);
      return;
    }

    // Only save if meaningful progress (> 10 seconds)
    if (positionSeconds < 10) return;

    _progressMap[contentId] = positionSeconds;

    if (seriesId != null) {
      _seriesProgressMap[seriesId] = contentId;
    }

    await _persist();
  }

  Future<void> removeProgress(String contentId, {String? seriesId}) async {
    bool changed = false;
    if (_progressMap.containsKey(contentId)) {
      _progressMap.remove(contentId);
      changed = true;
    }

    if (seriesId != null && _seriesProgressMap.containsKey(seriesId)) {
      // Only remove if the stored episode is the one being removed?
      // Or just remove the series entry.
      // User usually wants to clear "Resume Series".
      _seriesProgressMap.remove(seriesId);
      changed = true;
    }

    if (changed) await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(_progressMap));
    await prefs.setString(
      '${_storageKey}_series',
      json.encode(_seriesProgressMap),
    );
  }

  List<String> getInProgressContentIds() {
    // Return all individually in-progress items
    // If we want Series to appear in Resume list, we should include SeriesIDs too?
    // But ContentListScreen filters by ID. Series channels in ContentList have SeriesID.
    // So if I include Series IDs here, they will appear in RETOMAR!

    final ids = _progressMap.keys.toList();
    ids.addAll(_seriesProgressMap.keys);
    return ids.toSet().toList();
  }
}
