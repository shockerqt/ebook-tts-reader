import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../providers/library_provider.dart';
import '../widgets/book_card.dart';
import '../../../theme/dark_theme.dart';
import '../../../models/book.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryProvider);
    final isLoading = ref.watch(isLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Biblioteca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: books.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildBookGrid(context, ref, books),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : () => _importBook(context, ref),
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Icon(Icons.add),
        label: Text(isLoading ? 'Importando...' : 'Agregar libro'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 80,
            color: AppTheme.secondaryTextColor.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Tu biblioteca está vacía',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega un libro EPUB o PDF para comenzar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _importBook(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Importar libro'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookGrid(BuildContext context, WidgetRef ref, List<Book> books) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive columns based on available width
        const double minCardWidth = 160;
        const double maxCardWidth = 200;
        const double spacing = 16;
        
        final availableWidth = constraints.maxWidth - 32; // padding
        int crossAxisCount = (availableWidth / (minCardWidth + spacing)).floor();
        crossAxisCount = crossAxisCount.clamp(2, 6); // min 2, max 6 columns
        
        final cardWidth = (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
        final cardHeight = cardWidth / 0.65; // maintain aspect ratio
        
        return RefreshIndicator(
          onRefresh: () async {
            ref.read(libraryProvider.notifier).refreshBooks();
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.65,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return BookCard(
                book: book,
                onTap: () => context.push('/reader/${book.id}'),
                onLongPress: () => _showBookOptions(context, ref, book),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    ref.read(isLoadingProvider.notifier).state = true;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        await ref.read(libraryProvider.notifier).importBook(
              result.files.single.path!,
            );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Libro importado exitosamente')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e')),
        );
      }
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  void _showBookOptions(BuildContext context, WidgetRef ref, Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              book.title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              title: const Text('Eliminar libro'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref, book);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Eliminar libro'),
        content: Text('¿Estás seguro de que deseas eliminar "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).deleteBook(book);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Libro eliminado')),
              );
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
