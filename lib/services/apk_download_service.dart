import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'github_release_service.dart';

typedef ApkDownloadProgress = void Function(int receivedBytes, int totalBytes);

enum ApkDownloadStage { downloading, verifying }

extension on CancelToken {
  void throwIfCancellationRequested() {
    final error = cancelError;
    if (error != null) throw error;
  }
}

class ApkDownloadService {
  ApkDownloadService(
      {Dio? dio, Future<Directory> Function()? temporaryDirectory})
      : _dio = dio ??
            Dio(BaseOptions(connectTimeout: const Duration(seconds: 20))),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;

  Future<File> download(
    GitHubAppRelease release, {
    required CancelToken cancelToken,
    required ApkDownloadProgress onProgress,
    void Function(ApkDownloadStage)? onStage,
  }) async {
    final temporary = await _temporaryDirectory();
    final directory = Directory('${temporary.path}/faststore-updates');
    await directory.create(recursive: true);
    await for (final entity in directory.list(followLinks: false)) {
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
      cancelToken.throwIfCancellationRequested();
      onStage?.call(ApkDownloadStage.downloading);
      await _dio.download(
        release.downloadUrl,
        partialFile.path,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          receiveTimeout: const Duration(seconds: 45),
          headers: const {'Accept': 'application/vnd.android.package-archive'},
        ),
        onReceiveProgress: (received, total) => onProgress(
          received,
          total > 0 ? total : release.sizeBytes,
        ),
      );
      cancelToken.throwIfCancellationRequested();
      onStage?.call(ApkDownloadStage.verifying);
      await _verify(partialFile, release, cancelToken).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          cancelToken.cancel('APK verification timed out.');
          throw TimeoutException(
              'APK verification took too long. Please retry the update.');
        },
      );
      cancelToken.throwIfCancellationRequested();
      if (await apkFile.exists()) await apkFile.delete();
      cancelToken.throwIfCancellationRequested();
      return await partialFile.rename(apkFile.path);
    } catch (_) {
      await partialFile.delete().catchError((_) => partialFile);
      rethrow;
    }
  }

  Future<void> _verify(File partialFile, GitHubAppRelease release,
      CancelToken cancelToken) async {
    cancelToken.throwIfCancellationRequested();
    final length = await partialFile.length();
    if (length < 1024 * 1024 ||
        (release.sizeBytes > 0 && length != release.sizeBytes)) {
      throw const FormatException('The downloaded APK is incomplete.');
    }
    final header = await partialFile.open();
    late List<int> magic;
    try {
      magic = await header.read(4);
    } finally {
      await header.close();
    }
    if (magic.length < 4 || magic[0] != 0x50 || magic[1] != 0x4b) {
      throw const FormatException('The downloaded file is not a valid APK.');
    }
    if (release.sha256 != null) {
      final actualDigest = await _checksum(partialFile.path, cancelToken);
      if (actualDigest.toLowerCase() != release.sha256) {
        throw const FormatException('The APK checksum did not match GitHub.');
      }
    }
  }

  /// Hash large APKs off the UI isolate, and stop that worker on cancellation.
  Future<String> _checksum(String path, CancelToken cancelToken) async {
    final resultPort = ReceivePort();
    final errors = ReceivePort();
    Isolate? worker;
    try {
      worker = await Isolate.spawn(_hashApk, (path, resultPort.sendPort),
          onError: errors.sendPort, errorsAreFatal: true);
      return await Future.any<String>([
        resultPort.first.then((value) => value as String),
        errors.first.then((_) => throw StateError(
            'Could not verify the downloaded APK. Please retry.')),
        cancelToken.whenCancel.then((error) => throw error),
      ]);
    } finally {
      worker?.kill(priority: Isolate.immediate);
      resultPort.close();
      errors.close();
    }
  }
}

Future<void> _hashApk((String, SendPort) arguments) async {
  final digest = await sha256.bind(File(arguments.$1).openRead()).first;
  arguments.$2.send(digest.toString());
}
