/// Resposta de GET /health. A partir da etapa 1 os modelos passam a usar
/// freezed + json_serializable; aqui um fromJson manual basta.
class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.version,
    required this.environment,
    required this.database,
  });

  final String status;
  final String version;
  final String environment;
  final String database;

  bool get isHealthy => status == 'ok';

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      version: json['version'] as String? ?? '-',
      environment: json['environment'] as String? ?? '-',
      database: json['database'] as String? ?? 'unknown',
    );
  }
}
