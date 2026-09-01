class AppUpdateInfo {
  const AppUpdateInfo({
    required this.installedVersion,
    required this.latestVersion,
    this.apkUrl,
  });

  final String installedVersion;
  final String latestVersion;
  final String? apkUrl;

  bool get updateAvailable => isVersionNewer(latestVersion, installedVersion);
}

/// Compara a versão do pubspec e, quando presente, o versionCode depois de
/// `+`. O servidor usa o mesmo formato (`1.2.0+14`).
bool isVersionNewer(String candidate, String installed) {
  final next = _numericVersion(candidate);
  final current = _numericVersion(installed);
  final length = next.length > current.length ? next.length : current.length;

  for (var index = 0; index < length; index++) {
    final nextPart = index < next.length ? next[index] : 0;
    final currentPart = index < current.length ? current[index] : 0;
    if (nextPart != currentPart) return nextPart > currentPart;
  }
  return false;
}

List<int> _numericVersion(String value) {
  final parts = value.trim().split('+');
  final core = parts.first.split('.').map(int.parse).toList();
  if (parts.length > 1) core.add(int.parse(parts[1]));
  return core;
}
