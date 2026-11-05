import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/apk_download_service.dart';
import 'package:freshharvest_grocery/services/github_release_service.dart';

void main() {
  late Directory root;
  late HttpServer server;
  late ApkDownloadService service;
  final payload = Uint8List(1024 * 1024)..setRange(0, 4, [0x50, 0x4b, 3, 4]);
  late String digest;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('faststore-apk-test-');
    digest = sha256.convert(payload).toString();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = payload.length;
      request.response.add(payload);
      await request.response.close();
    });
    service = ApkDownloadService(temporaryDirectory: () async => root);
  });
  tearDown(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  GitHubAppRelease release({String? checksum, int? size}) => GitHubAppRelease(
        version: '3.1.6',
        name: 'Fixture',
        notes: '',
        publishedAt: null,
        downloadUrl: 'http://127.0.0.1:${server.port}/fixture.apk',
        fileName: 'fixture.apk',
        sizeBytes: size ?? payload.length,
        sha256: checksum ?? digest,
        htmlUrl: 'https://github.com/DevSidh/Ram-Prasad-Kirana-/releases',
        mandatory: false,
      );

  test('100 percent download proceeds through verification to a completed file',
      () async {
    final stages = <ApkDownloadStage>[];
    final file = await service.download(release(),
        cancelToken: CancelToken(),
        onProgress: (received, total) {},
        onStage: stages.add);
    expect(stages, [ApkDownloadStage.downloading, ApkDownloadStage.verifying]);
    expect(await file.length(), payload.length);
    expect(await File('${file.path}.part').exists(), isFalse);
  });

  test('verification cancellation is honored and a clean retry succeeds',
      () async {
    final token = CancelToken();
    await expectLater(
        service.download(release(),
            cancelToken: token,
            onProgress: (received, total) {}, onStage: (stage) {
          if (stage == ApkDownloadStage.verifying) {
            token.cancel('Fixture cancellation');
          }
        }),
        throwsA(isA<DioException>()
            .having(CancelToken.isCancel, 'cancelled', isTrue)));
    expect(await File('${root.path}/faststore-updates/fixture.apk').exists(),
        isFalse);
    final file = await service.download(release(),
        cancelToken: CancelToken(), onProgress: (received, total) {});
    expect(await file.exists(), isTrue);
  });

  test('a checksum mismatch cannot produce an installable completed file',
      () async {
    await expectLater(
        service.download(release(checksum: '0' * 64),
            cancelToken: CancelToken(), onProgress: (received, total) {}),
        throwsFormatException);
    expect(await File('${root.path}/faststore-updates/fixture.apk').exists(),
        isFalse);
    expect(
        await File('${root.path}/faststore-updates/fixture.apk.part').exists(),
        isFalse);
  });

  test('an incomplete APK is rejected even after network progress reaches 100',
      () async {
    await expectLater(
        service.download(release(size: payload.length + 1),
            cancelToken: CancelToken(), onProgress: (received, total) {}),
        throwsFormatException);
  });
}
