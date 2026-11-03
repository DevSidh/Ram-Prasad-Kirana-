import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Plays the store's bundled audio cues without interrupting application work.
class StoreAudioService {
  StoreAudioService._();

  static final AudioPlayer _startupPlayer = AudioPlayer();
  static final AudioPlayer _notificationPlayer = AudioPlayer();
  static final AudioPlayer _confirmationPlayer = AudioPlayer();

  static bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static final Map<String, String> _materializedAssets = {};

  static Future<void> playStartup() async {
    if (!_isWindows) return;
    await _play(_startupPlayer, 'audio/startup.wav');
  }

  static Future<void> playNotification() async {
    if (!_isWindows) return;
    await _play(_notificationPlayer, 'audio/notification.mp3');
  }

  static Future<void> playConfirmation() async {
    await _play(_confirmationPlayer, 'audio/confirmation.wav');
  }

  static Future<void> _play(AudioPlayer player, String asset) async {
    try {
      // Materialize the bundled asset first. This avoids Windows asset URI
      // resolution differences between debug runs and packaged releases.
      final path = await _materializeAsset(asset);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      await player.stop();
      await player.play(DeviceFileSource(path), volume: 1.0);
    } catch (error) {
      debugPrint('Could not play store audio $asset: $error');
    }
  }

  static Future<String> _materializeAsset(String asset) async {
    final cached = _materializedAssets[asset];
    if (cached != null && await File(cached).exists()) return cached;
    final data = await rootBundle.load('assets/$asset');
    final directory = await getTemporaryDirectory();
    final file =
        File('${directory.path}/faststore_${asset.replaceAll('/', '_')}');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    _materializedAssets[asset] = file.path;
    return file.path;
  }
}
