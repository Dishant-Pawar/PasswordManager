class PasswordItem {
  final int? id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  PasswordItem({
    this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.notes = '',
    this.category = 'General',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PasswordItem.fromMap(Map<String, dynamic> map) {
    return PasswordItem(
      id: map['id'],
      title: map['title'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      url: map['url'] ?? '',
      notes: map['notes'] ?? '',
      category: map['category'] ?? 'General',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  PasswordItem copyWith({
    int? id,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PasswordItem(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
