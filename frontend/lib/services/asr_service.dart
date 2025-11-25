import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'logging_service.dart';

class AsrService {
  static const String _asrUrl = String.fromEnvironment('ASR_URL');

  final _logger = LoggingService.logger;

  String get asrUrl {
    if (_asrUrl.isEmpty) {
      throw StateError('ASR_URL not configured. Add ASR_URL to .env file.');
    }
    return _asrUrl;
  }

  /// Strip WAV header (44 bytes) to get raw PCM data
  List<int> _wavToPcm(List<int> wavBytes) {
    if (wavBytes.length <= 44) return wavBytes;
    return wavBytes.sublist(44);
  }

  Future<String> transcribe(List<int> audioBytes, String languageCode) async {
    // On Linux we record WAV, need to strip header to get PCM
    final pcmBytes = Platform.isLinux ? _wavToPcm(audioBytes) : audioBytes;

    _logger.info('Transcribing audio via ASR service...', {
      'language': languageCode,
      'bytes': pcmBytes.length,
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$asrUrl/speak'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          pcmBytes,
          filename: 'audio.pcm',
        ),
      );

      request.fields['file_format'] = 'pcm_s16le_16';

      if (languageCode != 'auto' && languageCode.isNotEmpty) {
        request.fields['language_code'] = languageCode;
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final decoded = json.decode(responseBody);
        final text = decoded['text'] as String? ?? '';
        _logger.info('ASR transcription successful', {'text': text});
        return text;
      } else {
        final responseBody = await response.stream.bytesToString();
        _logger.warning('ASR request failed', {
          'status': response.statusCode,
          'body': responseBody,
        });
        throw Exception('ASR transcription failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error during ASR transcription: $e');
      rethrow;
    }
  }
}
