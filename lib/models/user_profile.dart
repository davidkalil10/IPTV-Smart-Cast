class UserProfile {
  final String id;
  final String name;
  final String url;
  final String username;
  final String password;
  final DateTime? expiryDate;

  UserProfile({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'password': password,
    'expiryDate': expiryDate?.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    name: json['name'],
    url: json['url'],
    username: json['username'],
    password: json['password'],
    expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : null,
  );
}
