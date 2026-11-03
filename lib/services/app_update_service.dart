import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_policy.dart';
import 'github_release_service.dart';

class AppUpdateCheck {
  const AppUpdateCheck({
    required this.currentVersion,
    required this.buildNumber,
    required this.release,
    required this.isMandatory,
  });

  final String currentVersion;
  final String buildNumber;
  final GitHubAppRelease? release;
  final bool isMandatory;

  bool get updateAvailable => release != null;
}

class AppUpdateService {
  AppUpdateService({GitHubReleaseService? releases})
      : _releases = releases ?? GitHubReleaseService();

  final GitHubReleaseService _releases;

  Future<AppUpdateCheck> checkForUpdate() async {
    final appInfo = await PackageInfo.fromPlatform();
    final currentVersion = appInfo.version;
    try {
      final latest = await _releases.fetchLatest();
      if (compareVersions(latest.version, currentVersion) <= 0) {
        return AppUpdateCheck(
          currentVersion: currentVersion,
          buildNumber: appInfo.buildNumber,
          release: null,
          isMandatory: false,
        );
      }
      return AppUpdateCheck(
        currentVersion: currentVersion,
        buildNumber: appInfo.buildNumber,
        release: latest,
        isMandatory: AppUpdatePolicy.requiresUpdate(
          currentVersion: currentVersion,
          availableVersion: latest.version,
          explicitlyConfigured: latest.mandatory,
        ),
      );
    } catch (_) {
      // Only a cached release covered by the app's explicit mandatory policy
      // may interrupt startup while GitHub is unavailable.
      final cached = await _releases.readCachedRelease();
      if (cached != null &&
          !kIsWeb &&
          Platform.isAndroid &&
          AppUpdatePolicy.requiresUpdate(
            currentVersion: currentVersion,
            availableVersion: cached.version,
            explicitlyConfigured: cached.mandatory,
          )) {
        return AppUpdateCheck(
          currentVersion: currentVersion,
          buildNumber: appInfo.buildNumber,
          release: cached,
          isMandatory: true,
        );
      }
      rethrow;
    }
  }
}
