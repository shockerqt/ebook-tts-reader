enum BookFormat { epub, pdf }

class Book {
  final String id;
  final String title;
  final String? author;
  final String filePath;
  final String? coverPath;
  final BookFormat format;
  final DateTime addedAt;
  int currentPage;
  int totalPages;
  String? currentChapterId;
  double lastScrollPosition;

  Book({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    this.coverPath,
    required this.format,
    required this.addedAt,
    this.currentPage = 0,
    this.totalPages = 0,
    this.currentChapterId,
    this.lastScrollPosition = 0.0,
  });

  double get progressPercent {
    if (totalPages == 0) return 0.0;
    return (currentPage / totalPages * 100).clamp(0.0, 100.0);
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? coverPath,
    BookFormat? format,
    DateTime? addedAt,
    int? currentPage,
    int? totalPages,
    String? currentChapterId,
    double? lastScrollPosition,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      format: format ?? this.format,
      addedAt: addedAt ?? this.addedAt,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      lastScrollPosition: lastScrollPosition ?? this.lastScrollPosition,
    );
  }

  // Convert to Map for Hive storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'coverPath': coverPath,
      'format': format.index,
      'addedAt': addedAt.toIso8601String(),
      'currentPage': currentPage,
      'totalPages': totalPages,
      'currentChapterId': currentChapterId,
      'lastScrollPosition': lastScrollPosition,
    };
  }

  // Create from Map
  factory Book.fromMap(Map<dynamic, dynamic> map) {
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      filePath: map['filePath'] as String,
      coverPath: map['coverPath'] as String?,
      format: BookFormat.values[map['format'] as int],
      addedAt: DateTime.parse(map['addedAt'] as String),
      currentPage: map['currentPage'] as int? ?? 0,
      totalPages: map['totalPages'] as int? ?? 0,
      currentChapterId: map['currentChapterId'] as String?,
      lastScrollPosition: (map['lastScrollPosition'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
