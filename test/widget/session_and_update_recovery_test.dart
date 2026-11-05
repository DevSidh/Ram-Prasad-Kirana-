import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/screens/cart/cart_screen.dart';
import 'package:freshharvest_grocery/screens/update/app_update_screen.dart';
import 'package:freshharvest_grocery/services/apk_download_service.dart';
import 'package:freshharvest_grocery/services/app_update_service.dart';
import 'package:freshharvest_grocery/services/github_release_service.dart';

class _ExpiredCart extends CartProvider {
  @override
  bool get requiresSignIn => true;
  @override
  String? get syncError => 'Your sign-in session has expired. Sign in again.';
}

class _PendingDownload extends ApkDownloadService {
  CancelToken? token;
  @override
  Future<File> download(
    GitHubAppRelease release, {
    required CancelToken cancelToken,
    required ApkDownloadProgress onProgress,
    void Function(ApkDownloadStage)? onStage,
  }) {
    token = cancelToken;
    onStage?.call(ApkDownloadStage.downloading);
    return cancelToken.whenCancel.then((error) => throw error);
  }
}

const _release = GitHubAppRelease(
    version: '3.1.6',
    name: 'Fixture',
    notes: '',
    publishedAt: null,
    downloadUrl:
        'https://github.com/DevSidh/Ram-Prasad-Kirana-/releases/download/v3.1.6/app.apk',
    fileName: 'app.apk',
    sizeBytes: 10000000,
    sha256: null,
    htmlUrl:
        'https://github.com/DevSidh/Ram-Prasad-Kirana-/releases/tag/v3.1.6',
    mandatory: false);

void main() {
  testWidgets('expired basket shows sign in instead of an endless retry',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<CartProvider>(
        create: (_) => _ExpiredCart(),
        child: const MaterialApp(home: CartScreen())));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sign in to restore your basket'), findsOneWidget);
    expect(find.text('Sign in again'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('optional download can be cancelled to return to the app',
      (tester) async {
    final downloads = _PendingDownload();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => AppUpdateScreen(
                                downloads: downloads,
                                initialCheck: const AppUpdateCheck(
                                    currentVersion: '3.1.5',
                                    buildNumber: '24',
                                    release: _release,
                                    isMandatory: false)))),
                    child: const Text('Open updater'))))));
    await tester.tap(find.text('Open updater'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.text('Update Now'), 250,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Update Now'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(downloads.token, isNotNull);
    await tester.tap(find.text('Cancel and continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(downloads.token!.isCancelled, isTrue);
    expect(find.text('Open updater'), findsOneWidget);
    expect(find.byType(AppUpdateScreen), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
