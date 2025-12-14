import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import 'progress_service.dart';

class SampleBookService {
  static const String _sampleBookAsset = 'assets/pride_and_prejudice.epub';
  static const String _sampleBookId = 'sample_pride_and_prejudice';

  final ProgressService _progressService;

  SampleBookService(this._progressService);

  Future<void> loadSampleBookIfNeeded() async {
    await _progressService.initialize();
    
    // Check if sample book already exists
    final existingBook = _progressService.getBook(_sampleBookId);
    if (existingBook != null) return;

    try {
      // Copy asset to app documents
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final targetPath = '${booksDir.path}/pride_and_prejudice.epub';
      
      // Load from assets and save to file
      final byteData = await rootBundle.load(_sampleBookAsset);
      final buffer = byteData.buffer;
      await File(targetPath).writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );

      // Create book entry
      final sampleBook = Book(
        id: _sampleBookId,
        title: 'Orgullo y Prejuicio',
        author: 'Jane Austen',
        filePath: targetPath,
        format: BookFormat.epub,
        addedAt: DateTime.now(),
        totalPages: 61, // Approximate chapters
      );

      await _progressService.saveBook(sampleBook);
    } catch (e) {
      // Silently fail if sample book can't be loaded
      print('Failed to load sample book: $e');
    }
  }
}

final sampleBookServiceProvider = Provider((ref) {
  final progressService = ref.watch(progressServiceProvider);
  return SampleBookService(progressService);
});
