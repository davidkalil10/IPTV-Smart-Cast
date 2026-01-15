import 'dart:convert';

class EpgProgram {
  final DateTime start;
  final DateTime end;
  final String title;
  final String description;

  EpgProgram({
    required this.start,
    required this.end,
    required this.title,
    required this.description,
  });

  factory EpgProgram.fromJson(Map<String, dynamic> json) {
    // Helper to decode Base64 if needed
    String cleanString(dynamic value) {
      if (value == null) return "";
      String str = value.toString();

      try {
        // Try decoding as Base64.
        // We trim whitespace just in case.
        // If it's pure alphabetical text without base64 chars, base64.decode might throw or produce garbage,
        // but typically valid base64 strings are distinct.
        // Xtream Codes EPG is almost always Base64 encoded if it looks like it.
        return utf8.decode(base64.decode(str));
      } catch (e) {
        // Fallback: try URI decoding
        try {
          return Uri.decodeComponent(str);
        } catch (_) {
          // Final fallback: return original
          return str;
        }
      }
    }

    DateTime parseDate(dynamic value) {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return EpgProgram(
      start: parseDate(json['start'] ?? json['start_timestamp']),
      end: parseDate(json['end'] ?? json['stop_timestamp']),
      title: cleanString(json['title']),
      description: cleanString(json['description']),
    );
  }

  bool get isCurrent {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }
}
