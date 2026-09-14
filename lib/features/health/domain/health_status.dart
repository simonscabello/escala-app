/// Resposta de GET /health, mais o que só o app sabe medir: quanto tempo a
/// resposta levou e quando a verificação foi feita.
class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.version,
    required this.environment,
    required this.database,
    this.commit,
    this.responseTime,
    this.checkedAt,
  });

  final String status;
  final String version;
  final String environment;
  final String database;

  /// Commit do build no ar, abreviado. Nulo fora do Railway.
  final String? commit;

  final Duration? responseTime;
  final DateTime? checkedAt;

  bool get isHealthy => status == 'ok';

  bool get databaseUp => database == 'up';

  /// "0.15.0 · a1b2c3d", ou só a versão quando não há commit.
  String get versionLabel =>
      commit == null || commit!.isEmpty ? version : '$version · $commit';

  factory HealthStatus.fromJson(
    Map<String, dynamic> json, {
    Duration? responseTime,
    DateTime? checkedAt,
  }) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      version: json['version'] as String? ?? '-',
      environment: json['environment'] as String? ?? '-',
      database: json['database'] as String? ?? 'unknown',
      commit: json['commit'] as String?,
      responseTime: responseTime,
      checkedAt: checkedAt,
    );
  }
}
