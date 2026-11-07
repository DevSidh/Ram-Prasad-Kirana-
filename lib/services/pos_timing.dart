import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

/// No customer/payment identifiers in timing logs. Optional file sink is used
/// by the Windows operator; logging never participates in the sale transaction.
class PosTiming {
  static String? logPath;
  static final samples = <String, List<int>>{};
  static Future<T> measure<T>(String stage, Future<T> Function() work) async {
    final watch = Stopwatch()..start();
    try {
      return await work();
    } finally {
      final micros = watch.elapsedMicroseconds;
      final values = samples.putIfAbsent(stage, () => []);
      if (values.length >= 100) values.removeAt(0);
      values.add(micros);
      developer.log('$stage: ${micros / 1000}ms', name: 'FastStore.POS');
      if (logPath != null) {
        try {
          final file = File(logPath!);
          await file.parent.create(recursive: true);
          if (await file.exists() && await file.length() > 1024 * 1024) {
            await file.rename('${file.path}.previous');
          }
          await file.writeAsString(
              '${jsonEncode({
                    'time': DateTime.now().toUtc().toIso8601String(),
                    'stage': stage,
                    'microseconds': micros
                  })}\n',
              mode: FileMode.append);
        } catch (_) {/* Diagnostics must not fail a saved bill. */}
      }
    }
  }
}
