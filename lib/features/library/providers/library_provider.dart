import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/book.dart';
import '../../../services/services.dart';

final libraryProvider = StateNotifierProvider<LibraryNotifier, List<Book>>((ref) {
  final progressService = ref.watch(progressServiceProvider);
  final bookService = ref.watch(bookServiceProvider);
  final sampleBookService = ref.watch(sampleBookServiceProvider);
  return LibraryNotifier(progressService, bookService, sampleBookService);
});

class LibraryNotifier extends StateNotifier<List<Book>> {
  final ProgressService _progressService;
  final BookService _bookService;
  final SampleBookService _sampleBookService;

  LibraryNotifier(this._progressService, this._bookService, this._sampleBookService) : super([]) {
    _initializeLibrary();
  }

  Future<void> _initializeLibrary() async {
    // Load sample book on first launch
    await _sampleBookService.loadSampleBookIfNeeded();
    // Then load all books
    await loadBooks();
  }

  Future<void> loadBooks() async {
    await _progressService.initialize();
    state = _progressService.getAllBooks();
  }

  Future<Book> importBook(String filePath) async {
    final book = await _bookService.importBook(filePath);
    state = [...state, book];
    return book;
  }

  Future<void> deleteBook(Book book) async {
    await _bookService.deleteBook(book);
    state = state.where((b) => b.id != book.id).toList();
  }

  void refreshBooks() {
    state = _progressService.getAllBooks();
  }
}

final isLoadingProvider = StateProvider<bool>((ref) => false);
