import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'github_release_service.dart';

typedef ApkDownloadProgress = void Function(int receivedBytes, int totalBytes);

class ApkDownloadService {
  ApkDownloadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<File> download(
    GitHubAppRelease release, {
    required CancelToken cancelToken,
    required ApkDownloadProgress onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    await directory.create(recursive: true);
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
    final safeName =
        release.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final partialFile = File('${directory.path}/$safeName.part');
    final apkFile = File('${directory.path}/$safeName');
    await partialFile.delete().catchError((_) => partialFile);

    try {
      await _dio.download(
        release.downloadUrl,
        partialFile.path,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          receiveTimeout: const Duration(minutes: 10),
          headers: const {'Accept': 'application/vnd.android.package-archive'},
        ),
        onReceiveProgress: (received, total) => onProgress(
          received,
          total > 0 ? total : release.sizeBytes,
        ),
      );
      final length = await partialFile.length();
      if (length < 1024 * 1024 ||
          (release.sizeBytes > 0 && length != release.sizeBytes)) {
        throw const FormatException('The downloaded APK is incomplete.');
      }
      final header = await partialFile.open();
      final magic = await header.read(4);
      await header.close();
      if (magic.length < 4 || magic[0] != 0x50 || magic[1] != 0x4b) {
        throw const FormatException('The downloaded file is not a valid APK.');
      }
      if (release.sha256 != null) {
        final actualDigest = await sha256.bind(partialFile.openRead()).first;
        if (actualDigest.toString().toLowerCase() != release.sha256) {
          throw const FormatException('The APK checksum did not match GitHub.');
        }
      }
      if (await apkFile.exists()) await apkFile.delete();
      return await partialFile.rename(apkFile.path);
    } catch (_) {
      await partialFile.delete().catchError((_) => partialFile);
      rethrow;
    }
  }
}
