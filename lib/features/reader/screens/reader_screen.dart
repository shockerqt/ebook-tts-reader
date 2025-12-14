import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_view/epub_view.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:html/parser.dart' as html_parser;
import '../../../models/book.dart';
import '../../../services/services.dart';
import '../../../theme/dark_theme.dart';
import '../../library/providers/library_provider.dart';
import '../widgets/tts_reading_view.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  Book? _book;
  bool _showControls = true;
  bool _showTTSPlayer = false;
  bool _showTTSReadingMode = false;
  EpubController? _epubController;
  PdfViewerController? _pdfController;
  
  // TTS state
  bool _ttsInitialized = false;
  bool _ttsGenerating = false;
  bool _ttsPlaying = false;
  String _ttsStatus = '';
  String? _currentChapterText;
  
  // Selected chapter for TTS
  String _selectedChapterText = '';
  String _selectedChapterTitle = '';

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    final progressService = ref.read(progressServiceProvider);
    await progressService.initialize();
    final book = progressService.getBook(widget.bookId);
    
    if (book != null) {
      setState(() => _book = book);
      
      if (book.format == BookFormat.epub) {
        _epubController = EpubController(
          document: EpubDocument.openFile(File(book.filePath)),
        );
      } else {
        _pdfController = PdfViewerController();
      }
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _epubController?.dispose();
    final ttsService = ref.read(ttsServiceProvider);
    ttsService.stop();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    if (_book == null) return;

    final progressService = ref.read(progressServiceProvider);
    
    if (_book!.format == BookFormat.epub && _epubController != null) {
      await progressService.updateProgress(
        bookId: _book!.id,
        currentPage: _epubController!.currentValueListenable.value?.chapterNumber ?? 0,
        currentChapterId: _epubController!.currentValueListenable.value?.chapter?.Title,
      );
    } else if (_book!.format == BookFormat.pdf && _pdfController != null) {
      await progressService.updateProgress(
        bookId: _book!.id,
        currentPage: _pdfController!.pageNumber ?? 0,
        totalPages: _pdfController!.pageCount ?? 0,
      );
    }
    
    ref.read(libraryProvider.notifier).refreshBooks();
  }

  @override
  Widget build(BuildContext context) {
    if (_book == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show TTS reading mode if active
    if (_showTTSReadingMode) {
      return TTSReadingView(
        text: _selectedChapterText,
        title: _selectedChapterTitle,
        onClose: () => setState(() => _showTTSReadingMode = false),
      );
    }

    return Scaffold(
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            _buildReader(),
            if (_showControls) _buildControls(),
            if (_showTTSPlayer) _buildTTSPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildReader() {
    if (_book!.format == BookFormat.epub && _epubController != null) {
      return _buildEpubReader();
    } else if (_book!.format == BookFormat.pdf) {
      return _buildPdfReader();
    }
    return const Center(child: Text('Formato no soportado'));
  }

  Widget _buildEpubReader() {
    return EpubView(
      controller: _epubController!,
      builders: EpubViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        chapterDividerBuilder: (_) => const Divider(height: 40),
        loaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => Center(
          child: Text(
            'Error al cargar: $error',
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfReader() {
    return PdfViewer.file(
      _book!.filePath,
      controller: _pdfController,
      params: PdfViewerParams(
        backgroundColor: AppTheme.backgroundColor,
        pageDropShadow: const BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset: Offset(2, 2),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
            stops: const [0.0, 0.15, 0.85, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Top bar
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        _saveProgress();
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Text(
                        _book!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.headphones, color: Colors.white),
                      onPressed: _openTTSReadingMode,
                      tooltip: 'Modo lectura TTS',
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Bottom bar with progress
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_book!.progressPercent.toStringAsFixed(0)}% completado',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTTSPlayer() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Status text
                Text(
                  _ttsStatus.isEmpty ? 'Listo para leer en voz alta' : _ttsStatus,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Stop button
                    IconButton(
                      onPressed: _ttsPlaying ? _stopTTS : null,
                      icon: const Icon(Icons.stop),
                      iconSize: 32,
                      color: _ttsPlaying ? AppTheme.textColor : AppTheme.dividerColor,
                    ),
                    const SizedBox(width: 16),
                    
                    // Play/Pause button
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _ttsGenerating ? null : (_ttsPlaying ? _pauseTTS : _playTTS),
                        icon: _ttsGenerating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Icon(_ttsPlaying ? Icons.pause : Icons.play_arrow),
                        iconSize: 40,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Close button
                    IconButton(
                      onPressed: () => setState(() => _showTTSPlayer = false),
                      icon: const Icon(Icons.close),
                      iconSize: 32,
                      color: AppTheme.textColor,
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Info text
                Text(
                  'Lee el capítulo actual en voz alta',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTTSReadingMode() async {
    // Check if models are downloaded
    final modelDownloader = ref.read(modelDownloaderProvider);
    final modelsReady = await modelDownloader.areModelsDownloaded();
    
    if (!modelsReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero descarga los modelos TTS en Configuración'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Show chapter selector
    if (_book!.format == BookFormat.epub && _epubController != null) {
      final chapters = _epubController!.tableOfContentsListenable.value;
      if (chapters != null && chapters.isNotEmpty) {
        final selectedChapter = await showModalBottomSheet<dynamic>(
          context: context,
          backgroundColor: AppTheme.surfaceColor,
          builder: (context) => _buildChapterSelector(chapters),
        );
        
        if (selectedChapter == null) return; // User cancelled
        
        // Get text from selected chapter
        final text = _extractChapterText(selectedChapter);
        if (text.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo extraer el texto del capítulo'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        
        _selectedChapterText = text;
        _selectedChapterTitle = selectedChapter.title ?? selectedChapter.Title ?? 'Capítulo';
        setState(() => _showTTSReadingMode = true);
        return;
      }
    }
    
    // Fallback: use current chapter
    final text = _getFullChapterText();
    if (text.isEmpty || text == 'No se pudo extraer el texto del capítulo.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo extraer el texto del capítulo'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    _selectedChapterText = text;
    _selectedChapterTitle = _book!.title;
    setState(() => _showTTSReadingMode = true);
  }

  Widget _buildChapterSelector(List<dynamic> chapters) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Selecciona un capítulo para leer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final title = chapter.title ?? chapter.Title ?? 'Capítulo ${index + 1}';
                return ListTile(
                  leading: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(color: AppTheme.textColor),
                  ),
                  onTap: () => Navigator.pop(context, chapter),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _extractChapterText(dynamic chapter) {
    try {
      // Try both property names as epub_view uses different conventions
      final htmlContent = chapter.HtmlContent ?? chapter.htmlContent;
      if (htmlContent != null && htmlContent.isNotEmpty) {
        final document = html_parser.parse(htmlContent);
        final text = document.body?.text ?? '';
        
        return text
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
            .trim();
      }
    } catch (e) {
      print('Error extracting chapter text: $e');
    }
    return '';
  }

  Future<void> _toggleTTSPlayer() async {
    if (!_showTTSPlayer) {
      // Check if models are downloaded
      final modelDownloader = ref.read(modelDownloaderProvider);
      final modelsReady = await modelDownloader.areModelsDownloaded();
      
      if (!modelsReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Primero descarga los modelos TTS en Configuración'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    
    setState(() => _showTTSPlayer = !_showTTSPlayer);
  }

  Future<void> _initializeTTS() async {
    if (_ttsInitialized) return;
    
    setState(() => _ttsStatus = 'Inicializando TTS...');
    
    final ttsService = ref.read(ttsServiceProvider);
    final success = await ttsService.initialize();
    
    if (success) {
      _ttsInitialized = true;
      setState(() => _ttsStatus = 'Listo');
    } else {
      setState(() => _ttsStatus = 'Error al inicializar TTS');
    }
  }

  String _getCurrentText() {
    if (_book!.format == BookFormat.epub && _epubController != null) {
      try {
        // Get current chapter from EPUB
        final currentValue = _epubController!.currentValueListenable.value;
        if (currentValue != null && currentValue.chapter != null) {
          final chapter = currentValue.chapter!;
          
          // Get the HTML content of the chapter
          final htmlContent = chapter.HtmlContent;
          if (htmlContent != null && htmlContent.isNotEmpty) {
            // Parse HTML and extract text
            final document = html_parser.parse(htmlContent);
            final text = document.body?.text ?? '';
            
            // Clean up the text
            final cleanText = text
                .replaceAll(RegExp(r'\s+'), ' ')
                .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
                .trim();
            
            if (cleanText.isNotEmpty) {
              // Limit to first ~2000 characters for reasonable TTS time
              final limitedText = cleanText.length > 2000 
                  ? '${cleanText.substring(0, 2000)}...' 
                  : cleanText;
              print('TTS Text length: ${limitedText.length} chars');
              return limitedText;
            }
          }
          
          // Fallback to chapter title
          return chapter.Title ?? 'Capítulo sin título';
        }
      } catch (e) {
        print('Error extracting EPUB text: $e');
      }
    }
    return 'Este es un texto de prueba para el sistema de texto a voz.';
  }

  // Get full chapter text for TTS reading mode (no limit)
  String _getFullChapterText() {
    if (_book!.format == BookFormat.epub && _epubController != null) {
      try {
        final currentValue = _epubController!.currentValueListenable.value;
        if (currentValue != null && currentValue.chapter != null) {
          final chapter = currentValue.chapter!;
          
          final htmlContent = chapter.HtmlContent;
          if (htmlContent != null && htmlContent.isNotEmpty) {
            final document = html_parser.parse(htmlContent);
            final text = document.body?.text ?? '';
            
            final cleanText = text
                .replaceAll(RegExp(r'\s+'), ' ')
                .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
                .trim();
            
            if (cleanText.isNotEmpty) {
              return cleanText;
            }
          }
          
          return chapter.Title ?? 'Capítulo sin título';
        }
      } catch (e) {
        print('Error extracting EPUB text: $e');
      }
    }
    return 'No se pudo extraer el texto del capítulo.';
  }

  Future<void> _playTTS() async {
    setState(() {
      _ttsGenerating = true;
      _ttsStatus = 'Inicializando...';
    });
    
    try {
      // Initialize TTS if needed
      await _initializeTTS();
      
      if (!_ttsInitialized) {
        setState(() {
          _ttsGenerating = false;
          _ttsStatus = 'Error: No se pudo inicializar TTS';
        });
        return;
      }
      
      // Get text to speak
      final text = _getCurrentText();
      
      setState(() => _ttsStatus = 'Generando audio...');
      
      final ttsService = ref.read(ttsServiceProvider);
      await ttsService.generateAndPlay(text);
      
      setState(() {
        _ttsGenerating = false;
        _ttsPlaying = true;
        _ttsStatus = 'Reproduciendo...';
      });
      
      // Listen for playback completion
      ttsService.playingStream.listen((playing) {
        if (mounted) {
          setState(() {
            _ttsPlaying = playing;
            if (!playing) {
              _ttsStatus = 'Listo';
            }
          });
        }
      });
    } catch (e) {
      setState(() {
        _ttsGenerating = false;
        _ttsStatus = 'Error: $e';
      });
    }
  }

  Future<void> _pauseTTS() async {
    final ttsService = ref.read(ttsServiceProvider);
    await ttsService.pause();
    setState(() {
      _ttsPlaying = false;
      _ttsStatus = 'Pausado';
    });
  }

  Future<void> _stopTTS() async {
    final ttsService = ref.read(ttsServiceProvider);
    await ttsService.stop();
    setState(() {
      _ttsPlaying = false;
      _ttsStatus = 'Listo';
    });
  }
}
