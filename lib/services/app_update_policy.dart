/// Mandatory status is accepted only from the explicit structured policy asset
/// validated by [GitHubReleaseService], never from release-note text.
class AppUpdatePolicy {
  AppUpdatePolicy._();

  static bool requiresUpdate({
    required String currentVersion,
    required String availableVersion,
    required bool explicitlyConfigured,
  }) =>
      explicitlyConfigured &&
      compareVersions(currentVersion, availableVersion) < 0;
}

int compareVersions(String left, String right) {
  final a = _versionParts(left);
  final b = _versionParts(right);
  if (a == null || b == null) {
    throw FormatException('Invalid app version: $left or $right');
  }
  for (var index = 0; index < 3; index++) {
    final comparison = a[index].compareTo(b[index]);
    if (comparison != 0) return comparison;
  }
  return 0;
}

List<int>? _versionParts(String value) {
  final match = RegExp(r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:[-+].*)?$')
      .firstMatch(value.trim());
  if (match == null) return null;
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3) ?? '0'),
  ];
}
