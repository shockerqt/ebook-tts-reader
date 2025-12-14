import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloaderService {
  // Correct Hugging Face URLs for Supertonic
  static const String _onnxBaseUrl =
      'https://huggingface.co/Supertone/supertonic/resolve/main/onnx';
  static const String _voiceBaseUrl =
      'https://huggingface.co/Supertone/supertonic/resolve/main/voice_styles';

  // Required ONNX models (in onnx/ folder)
  static const List<String> _requiredModels = [
    'duration_predictor.onnx',
    'text_encoder.onnx',
    'vector_estimator.onnx',
    'vocoder.onnx',
    'tts.json',
    'unicode_indexer.json',
  ];

  // Voice styles (in voice_styles/ folder)
  static const List<String> _voiceStyles = [
    'M1.json',
    'M2.json',
    'F1.json',
    'F2.json',
  ];

  final Dio _dio;

  ModelDownloaderService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
  ));

  Future<String> get _modelsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/supertonic_models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  Future<bool> areModelsDownloaded() async {
    final modelsPath = await _modelsDirectory;
    
    for (final model in _requiredModels) {
      final file = File('$modelsPath/$model');
      if (!await file.exists()) {
        return false;
      }
    }
    
    // Check at least one voice style
    final voiceDir = Directory('$modelsPath/voice_styles');
    if (!await voiceDir.exists()) {
      return false;
    }
    final voiceFile = File('$modelsPath/voice_styles/${_voiceStyles[0]}');
    if (!await voiceFile.exists()) {
      return false;
    }
    
    return true;
  }

  Future<void> downloadModels({
    required Function(double progress, String currentFile) onProgress,
    required Function() onComplete,
    required Function(String error) onError,
  }) async {
    try {
      final modelsPath = await _modelsDirectory;
      
      // Create voice_styles directory
      final voiceDir = Directory('$modelsPath/voice_styles');
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      
      final totalFiles = _requiredModels.length + _voiceStyles.length;
      var downloadedCount = 0;

      // Download ONNX models
      for (final model in _requiredModels) {
        final filePath = '$modelsPath/$model';
        
        // Skip if already exists
        if (await File(filePath).exists()) {
          downloadedCount++;
          onProgress(downloadedCount / totalFiles, '$model (cached)');
          continue;
        }

        final url = '$_onnxBaseUrl/$model';
        
        try {
          await _dio.download(
            url,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                final fileProgress = received / total;
                final overallProgress = (downloadedCount + fileProgress) / totalFiles;
                onProgress(overallProgress, model);
              }
            },
          );
          downloadedCount++;
        } catch (e) {
          throw Exception('Error downloading $model: $e');
        }
      }

      // Download voice styles
      for (final voice in _voiceStyles) {
        final filePath = '$modelsPath/voice_styles/$voice';
        
        // Skip if already exists
        if (await File(filePath).exists()) {
          downloadedCount++;
          onProgress(downloadedCount / totalFiles, '$voice (cached)');
          continue;
        }

        final url = '$_voiceBaseUrl/$voice';
        
        try {
          await _dio.download(
            url,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                final fileProgress = received / total;
                final overallProgress = (downloadedCount + fileProgress) / totalFiles;
                onProgress(overallProgress, voice);
              }
            },
          );
          downloadedCount++;
        } catch (e) {
          throw Exception('Error downloading $voice: $e');
        }
      }

      onComplete();
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<String> getModelPath(String modelName) async {
    final modelsPath = await _modelsDirectory;
    if (modelName.isEmpty) {
      return '$modelsPath/';
    }
    return '$modelsPath/$modelName';
  }

  Future<String> getVoicePath(String voiceId) async {
    final modelsPath = await _modelsDirectory;
    return '$modelsPath/voice_styles/$voiceId.json';
  }
  
  Future<String> getModelsDirectory() async {
    return await _modelsDirectory;
  }
}

final modelDownloaderProvider = Provider((ref) => ModelDownloaderService());
