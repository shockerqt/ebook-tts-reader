import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'tts_helper.dart';
import 'model_downloader_service.dart';

enum TTSStatus {
  notInitialized,
  initializing,
  ready,
  generating,
  playing,
  error,
}

class TTSService {
  final ModelDownloaderService _modelDownloader;
  
  TextToSpeech? _tts;
  Style? _currentStyle;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  TTSStatus _status = TTSStatus.notInitialized;
  String _statusMessage = 'Not initialized';
  String _currentVoiceId = 'M1';
  double _speed = 1.0;
  int _denoisingSteps = 5;
  
  TTSStatus get status => _status;
  String get statusMessage => _statusMessage;
  String get currentVoiceId => _currentVoiceId;
  double get speed => _speed;
  bool get isPlaying => _audioPlayer.playing;
  
  Stream<bool> get playingStream => _audioPlayer.playingStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  
  TTSService(this._modelDownloader);
  
  Future<bool> initialize() async {
    if (_status == TTSStatus.ready) return true;
    
    try {
      _status = TTSStatus.initializing;
      _statusMessage = 'Checking models...';
      
      final modelsReady = await _modelDownloader.areModelsDownloaded();
      print('TTS: Models downloaded: $modelsReady');
      
      if (!modelsReady) {
        _status = TTSStatus.notInitialized;
        _statusMessage = 'Models not downloaded';
        return false;
      }
      
      _statusMessage = 'Loading TTS models...';
      final modelsPath = await _modelDownloader.getModelsDirectory();
      print('TTS: Models path: $modelsPath');
      
      _tts = await loadTextToSpeech(modelsPath);
      print('TTS: TextToSpeech loaded successfully');
      
      _statusMessage = 'Loading voice style...';
      final voicePath = await _modelDownloader.getVoicePath(_currentVoiceId);
      print('TTS: Voice path: $voicePath');
      
      _currentStyle = await loadVoiceStyle([voicePath]);
      print('TTS: Voice style loaded successfully');
      
      _status = TTSStatus.ready;
      _statusMessage = 'Ready';
      return true;
    } catch (e, stackTrace) {
      print('TTS Error: $e');
      print('TTS Stack: $stackTrace');
      _status = TTSStatus.error;
      _statusMessage = 'Error: $e';
      return false;
    }
  }
  
  Future<void> setVoice(String voiceId) async {
    if (_tts == null) return;
    
    try {
      _currentVoiceId = voiceId;
      final voicePath = await _modelDownloader.getVoicePath(voiceId);
      _currentStyle = await loadVoiceStyle([voicePath]);
    } catch (e) {
      _statusMessage = 'Error loading voice: $e';
    }
  }
  
  void setSpeed(double speed) {
    _speed = speed.clamp(0.5, 2.0);
  }
  
  void setDenoisingSteps(int steps) {
    _denoisingSteps = steps.clamp(1, 20);
  }
  
  Future<String?> generateSpeech(String text) async {
    if (_tts == null || _currentStyle == null) {
      _statusMessage = 'TTS not initialized';
      return null;
    }
    
    if (text.trim().isEmpty) {
      _statusMessage = 'No text to generate';
      return null;
    }
    
    try {
      _status = TTSStatus.generating;
      _statusMessage = 'Generating speech...';
      
      final result = await _tts!.call(
        text,
        _currentStyle!,
        _denoisingSteps,
        speed: _speed,
      );
      
      final wav = result['wav'] is List<double>
          ? result['wav'] as List<double>
          : (result['wav'] as List).cast<double>();
      
      // Save to file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/tts_$timestamp.wav';
      
      writeWavFile(outputPath, wav, _tts!.sampleRate);
      
      _status = TTSStatus.ready;
      _statusMessage = 'Generated';
      
      return outputPath;
    } catch (e, stackTrace) {
      print('TTS generateSpeech error: $e');
      print('TTS generateSpeech stack: $stackTrace');
      _status = TTSStatus.error;
      _statusMessage = 'Error generating: $e';
      return null;
    }
  }
  
  Future<void> generateAndPlay(String text) async {
    final audioPath = await generateSpeech(text);
    if (audioPath != null) {
      await playAudio(audioPath);
    }
  }
  
  Future<void> playAudio(String filePath) async {
    try {
      _status = TTSStatus.playing;
      _statusMessage = 'Playing...';
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found');
      }
      
      // Stop any previous playback first
      await _audioPlayer.stop();
      
      // Load the file and wait for it to be ready
      await _audioPlayer.setFilePath(filePath);
      
      // Small delay to ensure player is ready (workaround for just_audio_windows threading issue)
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Wait for player to be in ready state
      await _audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.ready,
      ).timeout(const Duration(seconds: 2), onTimeout: () {
        // If timeout, try playing anyway
        return _audioPlayer.playerState;
      });
      
      // Now play
      await _audioPlayer.play();
    } catch (e) {
      _status = TTSStatus.error;
      _statusMessage = 'Error playing: $e';
    }
  }
  
  /// Wait for the current audio to finish playing
  Future<void> waitForCompletion() async {
    // Wait until audio is done
    await _audioPlayer.playerStateStream.firstWhere(
      (state) => state.processingState == ProcessingState.completed,
    );
    _status = TTSStatus.ready;
    _statusMessage = 'Ready';
  }
  
  Future<void> pause() async {
    await _audioPlayer.pause();
  }
  
  Future<void> resume() async {
    await _audioPlayer.play();
  }
  
  Future<void> stop() async {
    await _audioPlayer.stop();
    _status = TTSStatus.ready;
    _statusMessage = 'Ready';
  }
  
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }
  
  void dispose() {
    _audioPlayer.dispose();
  }
}

final ttsServiceProvider = Provider((ref) {
  final modelDownloader = ref.watch(modelDownloaderProvider);
  return TTSService(modelDownloader);
});

final ttsStatusProvider = StreamProvider<TTSStatus>((ref) async* {
  final ttsService = ref.watch(ttsServiceProvider);
  yield ttsService.status;
});
