class Channel {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String category;
  final bool isFavorite;
  final double? rating;
  final String type; // 'live', 'movie', 'series'

  Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    required this.category,
    this.isFavorite = false,
    this.rating,
    this.type = 'live',
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      streamUrl: json['url'] ?? '',
      logoUrl: json['logo'],
      category: json['category'] ?? 'Geral',
      isFavorite: json['isFavorite'] ?? false,
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      type: json['type'] ?? 'live',
    );
  }
}
