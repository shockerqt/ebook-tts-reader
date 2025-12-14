import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/book.dart';

class ProgressService {
  static const String _booksBoxName = 'books';
  late Box _booksBox;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _booksBox = await Hive.openBox(_booksBoxName);
    _initialized = true;
  }

  List<Book> getAllBooks() {
    return _booksBox.keys.map((key) {
      final map = _booksBox.get(key) as Map<dynamic, dynamic>;
      return Book.fromMap(map);
    }).toList();
  }

  Book? getBook(String id) {
    final map = _booksBox.get(id);
    if (map == null) return null;
    return Book.fromMap(map as Map<dynamic, dynamic>);
  }

  Future<void> saveBook(Book book) async {
    await _booksBox.put(book.id, book.toMap());
  }

  Future<void> deleteBook(String id) async {
    await _booksBox.delete(id);
  }

  Future<void> updateProgress({
    required String bookId,
    required int currentPage,
    int? totalPages,
    String? currentChapterId,
    double? scrollPosition,
  }) async {
    final book = getBook(bookId);
    if (book != null) {
      final updated = book.copyWith(
        currentPage: currentPage,
        totalPages: totalPages ?? book.totalPages,
        currentChapterId: currentChapterId ?? book.currentChapterId,
        lastScrollPosition: scrollPosition ?? book.lastScrollPosition,
      );
      await saveBook(updated);
    }
  }

  List<Book> getRecentBooks({int limit = 5}) {
    final books = getAllBooks();
    books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return books.take(limit).toList();
  }

  List<Book> getInProgressBooks() {
    return getAllBooks()
        .where((book) => book.progressPercent > 0 && book.progressPercent < 100)
        .toList();
  }
}

final progressServiceProvider = Provider((ref) => ProgressService());
