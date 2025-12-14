import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/services.dart';
import '../../../theme/dark_theme.dart';

class TTSReadingView extends ConsumerStatefulWidget {
  final String text;
  final String title;
  final VoidCallback onClose;

  const TTSReadingView({
    super.key,
    required this.text,
    required this.title,
    required this.onClose,
  });

  @override
  ConsumerState<TTSReadingView> createState() => _TTSReadingViewState();
}

class _TTSReadingViewState extends ConsumerState<TTSReadingView> {
  final ScrollController _scrollController = ScrollController();
  
  List<String> _sentences = [];
  int _currentSentenceIndex = 0;
  bool _isPlaying = false;
  bool _isGenerating = false;
  bool _isPaused = false;
  String _status = 'Listo';
  
  // Keys for scrolling to sentences
  final List<GlobalKey> _sentenceKeys = [];
  
  // Preloading: cache of generated audio paths
  final Map<int, String> _audioCache = {};
  
  // Per-sentence loading state
  final Set<int> _loadingSentences = {};

  @override
  void initState() {
    super.initState();
    _splitIntoSentences();
  }

  void _splitIntoSentences() {
    // Split text into sentences
    final regex = RegExp(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÑ])');
    _sentences = widget.text
        .split(regex)
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    
    // Create keys for each sentence
    _sentenceKeys.clear();
    for (var i = 0; i < _sentences.length; i++) {
      _sentenceKeys.add(GlobalKey());
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    final ttsService = ref.read(ttsServiceProvider);
    ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            final ttsService = ref.read(ttsServiceProvider);
            ttsService.stop();
            widget.onClose();
          },
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Sentence counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_currentSentenceIndex + 1} / ${_sentences.length}',
                style: const TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.cardColor,
            child: Row(
              children: [
                if (_isGenerating)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_isGenerating) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: _status.startsWith('Error') 
                          ? AppTheme.errorColor 
                          : AppTheme.secondaryTextColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Text display
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              itemCount: _sentences.length,
              itemBuilder: (context, index) {
                final isCurrentSentence = index == _currentSentenceIndex;
                final isPastSentence = index < _currentSentenceIndex;
                final isLoading = _loadingSentences.contains(index);
                final isCached = _audioCache.containsKey(index);
                
                // Text widget (always fully opaque)
                final textWidget = Text(
                  _sentences[index],
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.6,
                    color: isPastSentence
                        ? AppTheme.secondaryTextColor
                        : isCurrentSentence
                            ? AppTheme.textColor
                            : AppTheme.textColor.withValues(alpha: 0.8),
                    fontWeight: isCurrentSentence 
                        ? FontWeight.w500 
                        : FontWeight.normal,
                  ),
                );
                
                // Background color
                Color bgColor = isCurrentSentence 
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : isCached
                        ? Colors.green.withValues(alpha: 0.08)
                        : isLoading
                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                            : Colors.transparent;
                
                // Border
                Border? border = isCurrentSentence
                    ? Border.all(color: AppTheme.primaryColor, width: 2)
                    : isCached
                        ? Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1)
                        : null;
                
                Widget sentenceWidget;
                
                if (isLoading) {
                  // Use Stack: pulsing background + solid text on top
                  sentenceWidget = Container(
                    key: _sentenceKeys[index],
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Stack(
                      children: [
                        // Pulsing background layer
                        Positioned.fill(
                          child: _PulsingContainer(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Solid text layer
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: textWidget,
                        ),
                      ],
                    ),
                  );
                } else {
                  // Normal container
                  sentenceWidget = Container(
                    key: _sentenceKeys[index],
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: border,
                    ),
                    child: textWidget,
                  );
                }
                
                return GestureDetector(
                  onTap: () => _jumpToSentence(index),
                  child: sentenceWidget,
                );
              },
            ),
          ),
          
          // Controls
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous sentence
            IconButton(
              onPressed: _currentSentenceIndex > 0 ? _previousSentence : null,
              icon: const Icon(Icons.skip_previous),
              iconSize: 36,
              color: _currentSentenceIndex > 0 
                  ? AppTheme.textColor 
                  : AppTheme.dividerColor,
            ),
            const SizedBox(width: 16),
            
            // Stop
            IconButton(
              onPressed: _isPlaying || _isPaused ? _stop : null,
              icon: const Icon(Icons.stop),
              iconSize: 36,
              color: _isPlaying || _isPaused 
                  ? AppTheme.textColor 
                  : AppTheme.dividerColor,
            ),
            const SizedBox(width: 16),
            
            // Play/Pause
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isGenerating ? null : (_isPlaying ? _pause : _play),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      )
                    : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 44,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            
            // Next sentence
            IconButton(
              onPressed: _currentSentenceIndex < _sentences.length - 1 
                  ? _nextSentence 
                  : null,
              icon: const Icon(Icons.skip_next),
              iconSize: 36,
              color: _currentSentenceIndex < _sentences.length - 1 
                  ? AppTheme.textColor 
                  : AppTheme.dividerColor,
            ),
            const SizedBox(width: 16),
            
            // Restart
            IconButton(
              onPressed: () => _jumpToSentence(0),
              icon: const Icon(Icons.replay),
              iconSize: 36,
              color: AppTheme.textColor,
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToCurrentSentence() {
    if (_sentenceKeys.isEmpty || _currentSentenceIndex >= _sentenceKeys.length) {
      return;
    }
    
    final key = _sentenceKeys[_currentSentenceIndex];
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  Future<void> _play() async {
    if (_sentences.isEmpty) return;
    
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
    
    // Start playing from current sentence
    await _playSentence(_currentSentenceIndex);
  }

  Future<void> _playSentence(int index) async {
    if (!_isPlaying || index >= _sentences.length) {
      setState(() {
        _isPlaying = false;
        _status = 'Completado';
      });
      return;
    }
    
    setState(() {
      _currentSentenceIndex = index;
      _status = 'Preparando...';
    });
    
    _scrollToCurrentSentence();
    
    try {
      final ttsService = ref.read(ttsServiceProvider);
      
      // Initialize if needed
      if (ttsService.status != TTSStatus.ready) {
        setState(() => _status = 'Inicializando TTS...');
        final success = await ttsService.initialize();
        if (!success) {
          setState(() {
            _isGenerating = false;
            _isPlaying = false;
            _status = 'Error: No se pudo inicializar TTS';
          });
          return;
        }
      }
      
      // Check if audio is already cached
      String? audioPath = _audioCache[index];
      
      if (audioPath == null) {
        // Need to generate - batch setState
        _isGenerating = true;
        _loadingSentences.add(index);
        final sentence = _sentences[index];
        final previewText = sentence.length > 30 
            ? '${sentence.substring(0, 30)}...' 
            : sentence;
        _status = 'Generando: "$previewText"';
        setState(() {});
        
        audioPath = await ttsService.generateSpeech(sentence);
        
        _loadingSentences.remove(index);
        
        if (audioPath == null || !_isPlaying) {
          setState(() {
            _isGenerating = false;
            _isPlaying = false;
            _status = 'Error al generar audio';
          });
          return;
        }
        
        // Cache the audio path
        _audioCache[index] = audioPath;
      }
      
      // Batch update state
      _isGenerating = false;
      _status = 'Reproduciendo...';
      setState(() {});
      
      // Preload next 3 sentences while this one plays
      _preloadMultipleSentences(index + 1, 3, ttsService);
      
      // Play the audio and wait for completion
      await ttsService.playAudio(audioPath);
      
      // Wait for playback to actually complete
      await _waitForPlaybackComplete(ttsService);
      
      // If still playing mode, move to next sentence (with pause between sentences)
      if (_isPlaying && index < _sentences.length - 1) {
        // Delay to simulate natural pause at period
        await Future.delayed(const Duration(milliseconds: 500));
        if (_isPlaying) { // Check again after delay
          await _playSentence(index + 1);
        }
      } else {
        setState(() {
          _isPlaying = false;
          _status = index >= _sentences.length - 1 ? 'Completado' : 'Listo';
        });
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _isPlaying = false;
        _status = 'Error: $e';
      });
    }
  }

  // Preload sentence in background (non-blocking)
  Future<void> _preloadSentence(int index, TTSService ttsService) async {
    if (_audioCache.containsKey(index) || _loadingSentences.contains(index)) {
      return; // Already cached or loading
    }
    
    if (index >= _sentences.length) return;
    
    _loadingSentences.add(index);
    if (mounted) setState(() {});
    
    try {
      final sentence = _sentences[index];
      final audioPath = await ttsService.generateSpeech(sentence);
      
      if (audioPath != null && mounted) {
        _audioCache[index] = audioPath;
      }
    } catch (e) {
      print('Preload error for sentence $index: $e');
    } finally {
      _loadingSentences.remove(index);
      if (mounted) setState(() {});
    }
  }

  // Preload multiple sentences at once (non-blocking)
  void _preloadMultipleSentences(int startIndex, int count, TTSService ttsService) {
    for (var i = 0; i < count; i++) {
      final index = startIndex + i;
      if (index < _sentences.length && !_audioCache.containsKey(index) && !_loadingSentences.contains(index)) {
        _preloadSentence(index, ttsService);
      }
    }
  }

  Future<void> _waitForPlaybackComplete(TTSService ttsService) async {
    try {
      // Use the service's built-in wait for completion
      await ttsService.waitForCompletion();
    } catch (e) {
      // If cancelled or error, just return
      print('Playback wait interrupted: $e');
    }
  }

  void _pause() {
    final ttsService = ref.read(ttsServiceProvider);
    ttsService.pause();
    setState(() {
      _isPlaying = false;
      _isPaused = true;
      _status = 'Pausado';
    });
  }

  void _stop() {
    final ttsService = ref.read(ttsServiceProvider);
    ttsService.stop();
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _status = 'Listo';
    });
  }

  void _previousSentence() {
    if (_currentSentenceIndex > 0) {
      final wasPlaying = _isPlaying;
      _stopAudioOnly();
      setState(() => _currentSentenceIndex--);
      _scrollToCurrentSentence();
      if (wasPlaying) _play();
    }
  }

  void _nextSentence() {
    if (_currentSentenceIndex < _sentences.length - 1) {
      final wasPlaying = _isPlaying;
      _stopAudioOnly();
      setState(() => _currentSentenceIndex++);
      _scrollToCurrentSentence();
      if (wasPlaying) _play();
    }
  }

  void _jumpToSentence(int index) {
    if (index == _currentSentenceIndex) return;
    final wasPlaying = _isPlaying;
    _stopAudioOnly();
    setState(() => _currentSentenceIndex = index);
    _scrollToCurrentSentence();
    if (wasPlaying) _play();
  }
  
  // Stop audio without changing isPlaying state
  void _stopAudioOnly() {
    final ttsService = ref.read(ttsServiceProvider);
    ttsService.stop();
    setState(() {
      _isGenerating = false;
      _isPaused = false;
    });
  }
}

// Pulsing container that only animates the background opacity
class _PulsingContainer extends StatefulWidget {
  final Color color;
  final BorderRadius borderRadius;

  const _PulsingContainer({
    required this.color,
    required this.borderRadius,
  });

  @override
  State<_PulsingContainer> createState() => _PulsingContainerState();
}

class _PulsingContainerState extends State<_PulsingContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: widget.color.a * _animation.value),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}
