import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import 'progress_service.dart';

class BookService {
  final ProgressService _progressService;
  final Uuid _uuid = const Uuid();

  BookService(this._progressService);

  Future<Book> importBook(String filePath) async {
    final file = File(filePath);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final extension = fileName.split('.').last.toLowerCase();

    BookFormat format;
    if (extension == 'epub') {
      format = BookFormat.epub;
    } else if (extension == 'pdf') {
      format = BookFormat.pdf;
    } else {
      throw Exception('Unsupported format: $extension');
    }

    // Copy file to app documents
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final bookId = _uuid.v4();
    final newPath = '${booksDir.path}/$bookId.$extension';
    await file.copy(newPath);

    // Extract metadata (simplified for now)
    String title = fileName.replaceAll('.$extension', '');
    String? author;
    String? coverPath;

    // TODO: Extract actual metadata from EPUB/PDF

    final book = Book(
      id: bookId,
      title: title,
      author: author,
      filePath: newPath,
      coverPath: coverPath,
      format: format,
      addedAt: DateTime.now(),
    );

    await _progressService.saveBook(book);
    return book;
  }

  Future<void> deleteBook(Book book) async {
    // Delete the file
    final file = File(book.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Delete cover if exists
    if (book.coverPath != null) {
      final coverFile = File(book.coverPath!);
      if (await coverFile.exists()) {
        await coverFile.delete();
      }
    }

    // Remove from database
    await _progressService.deleteBook(book.id);
  }
}

final bookServiceProvider = Provider((ref) {
  final progressService = ref.watch(progressServiceProvider);
  return BookService(progressService);
});
