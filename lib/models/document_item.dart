class DocumentItem {
  final int? id;
  final String name;
  final String filePath;
  final String fileType;
  final int sizeBytes;
  final DateTime createdAt;

  DocumentItem({
    this.id,
    required this.name,
    required this.filePath,
    required this.fileType,
    required this.sizeBytes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'fileType': fileType,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'],
      name: map['name'] ?? '',
      filePath: map['filePath'] ?? '',
      fileType: map['fileType'] ?? '',
      sizeBytes: map['sizeBytes'] ?? 0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }

  DocumentItem copyWith({
    int? id,
    String? name,
    String? filePath,
    String? fileType,
    int? sizeBytes,
    DateTime? createdAt,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
