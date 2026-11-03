import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/app_update_policy.dart';
import 'package:freshharvest_grocery/services/github_release_service.dart';

void main() {
  group('app update version policy', () {
    test('compares numeric semantic versions and ignores build metadata', () {
      expect(compareVersions('v3.1.10', '3.1.4'), greaterThan(0));
      expect(compareVersions('3.2', '3.1.99'), greaterThan(0));
      expect(compareVersions('3.1.4+23', '3.1.4'), 0);
    });

    test('mandatory status requires a validated explicit policy', () {
      expect(
        AppUpdatePolicy.requiresUpdate(
          currentVersion: '3.1.3',
          availableVersion: '3.1.4',
          explicitlyConfigured: false,
        ),
        isFalse,
      );
      expect(
        AppUpdatePolicy.requiresUpdate(
          currentVersion: '3.1.3',
          availableVersion: '3.1.4',
          explicitlyConfigured: true,
        ),
        isTrue,
      );
    });
  });

  group('GitHub stable release parsing', () {
    test('finds the APK and its trusted SHA-256 digest', () {
      final release = GitHubAppRelease.fromJson(_release());
      expect(release.version, '3.1.4');
      expect(release.fileName, 'FastStore-3.1.4.apk');
      expect(release.sizeBytes, 5 * 1024 * 1024);
      expect(release.sha256, 'a' * 64);
      expect(release.mandatory, isFalse);
    });

    test('release note wording cannot make an update mandatory', () {
      final release = GitHubAppRelease.fromJson(
        _release()..['body'] = 'MANDATORY UPDATE: install now',
      );
      expect(release.mandatory, isFalse);
    });

    test('accepts mandatory only from a matching structured policy asset', () {
      final json = _release()
        ..['_faststore_verified_update_policy'] = {
          'schemaVersion': 1,
          'appId': 'com.freshharvest.grocery_app',
          'releaseVersion': '3.1.4',
          'mandatory': true,
        };
      expect(GitHubAppRelease.fromJson(json).mandatory, isTrue);
    });

    test('ignores policy for a different application or release', () {
      final json = _release()
        ..['_faststore_verified_update_policy'] = {
          'schemaVersion': 1,
          'appId': 'other.app',
          'releaseVersion': '3.1.4',
          'mandatory': true,
        };
      expect(GitHubAppRelease.fromJson(json).mandatory, isFalse);
    });

    test('rejects draft and prerelease releases', () {
      expect(
        () => GitHubAppRelease.fromJson(_release()..['draft'] = true),
        throwsFormatException,
      );
      expect(
        () => GitHubAppRelease.fromJson(_release()..['prerelease'] = true),
        throwsFormatException,
      );
    });

    test('reports a clear error when the release has no APK', () {
      final json = _release()..['assets'] = <Map<String, dynamic>>[];
      expect(
        () => GitHubAppRelease.fromJson(json),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('no APK asset'),
        )),
      );
    });

    test('rejects APK download links outside the official HTTPS host', () {
      final json = _release();
      (json['assets'] as List<Map<String, dynamic>>)
          .single['browser_download_url'] = 'http://example.com/app.apk';
      expect(() => GitHubAppRelease.fromJson(json), throwsFormatException);
    });
  });
}

Map<String, dynamic> _release() => {
      'tag_name': 'v3.1.4',
      'name': 'FastStore 3.1.4',
      'body': '- Bug fixes',
      'draft': false,
      'prerelease': false,
      'published_at': '2026-10-27T17:33:56Z',
      'html_url':
          'https://github.com/DevSidh/Ram-Prasad-Kirana-/releases/tag/v3.1.4',
      'assets': <Map<String, dynamic>>[
        {
          'name': 'FastStore-3.1.4.apk',
          'content_type': 'application/vnd.android.package-archive',
          'size': 5 * 1024 * 1024,
          'digest': 'sha256:${'a' * 64}',
          'browser_download_url':
              'https://github.com/DevSidh/Ram-Prasad-Kirana-/releases/download/v3.1.4/FastStore-3.1.4.apk',
        },
      ],
    };
