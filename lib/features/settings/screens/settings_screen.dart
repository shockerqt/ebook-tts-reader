import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/dark_theme.dart';
import '../../../models/voice.dart';
import '../../../services/services.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Voice _selectedVoice = Voice.availableVoices.first;
  double _speed = 1.0;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  bool _modelsDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkModelsStatus();
  }

  Future<void> _checkModelsStatus() async {
    final modelDownloader = ref.read(modelDownloaderProvider);
    final downloaded = await modelDownloader.areModelsDownloaded();
    setState(() => _modelsDownloaded = downloaded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Modelos TTS',
            children: [
              _buildModelStatus(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Voz',
            children: [
              _buildVoiceSelector(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Velocidad de lectura',
            children: [
              _buildSpeedSlider(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Acerca de',
            children: [
              _buildAboutTile(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.primaryColor,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildModelStatus() {
    if (_isDownloading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _downloadStatus,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: AppTheme.dividerColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListTile(
      leading: Icon(
        _modelsDownloaded ? Icons.check_circle : Icons.download,
        color: _modelsDownloaded ? AppTheme.progressColor : AppTheme.primaryColor,
      ),
      title: Text(
        _modelsDownloaded ? 'Modelos descargados' : 'Descargar modelos TTS',
      ),
      subtitle: Text(
        _modelsDownloaded
            ? 'Listo para usar Supertonic TTS'
            : '~200 MB requeridos',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: _modelsDownloaded
          ? null
          : ElevatedButton(
              onPressed: _downloadModels,
              child: const Text('Descargar'),
            ),
    );
  }

  Widget _buildVoiceSelector() {
    return Column(
      children: Voice.availableVoices.map((voice) {
        final isSelected = _selectedVoice.id == voice.id;
        return ListTile(
          leading: Icon(
            voice.gender == 'male' ? Icons.person : Icons.person_outline,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
          ),
          title: Text(voice.name),
          subtitle: Text(
            voice.gender == 'male' ? 'Masculina' : 'Femenina',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: isSelected
              ? const Icon(Icons.check, color: AppTheme.primaryColor)
              : null,
          onTap: () {
            setState(() => _selectedVoice = voice);
            // Update TTS service voice
            final ttsService = ref.read(ttsServiceProvider);
            ttsService.setVoice(voice.id);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSpeedSlider() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0.5x'),
              Text(
                '${_speed.toStringAsFixed(1)}x',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
              ),
              const Text('2.0x'),
            ],
          ),
          Slider(
            value: _speed,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            onChanged: (value) {
              setState(() => _speed = value);
              // Update TTS service speed
              final ttsService = ref.read(ttsServiceProvider);
              ttsService.setSpeed(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Ebook TTS Reader'),
      subtitle: const Text('v1.0.0 • Powered by Supertonic'),
      onTap: () {
        showAboutDialog(
          context: context,
          applicationName: 'Ebook TTS Reader',
          applicationVersion: '1.0.0',
          applicationLegalese: '© 2024',
          children: [
            const SizedBox(height: 16),
            const Text(
              'Lector de ebooks con TTS on-device usando Supertonic.',
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadModels() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Iniciando descarga...';
    });

    final modelDownloader = ref.read(modelDownloaderProvider);
    
    await modelDownloader.downloadModels(
      onProgress: (progress, currentFile) {
        setState(() {
          _downloadProgress = progress;
          _downloadStatus = 'Descargando: $currentFile';
        });
      },
      onComplete: () {
        setState(() {
          _isDownloading = false;
          _modelsDownloaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modelos descargados exitosamente')),
        );
      },
      onError: (error) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = 'Error: $error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      },
    );
  }
}
