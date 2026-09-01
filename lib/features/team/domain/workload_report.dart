class WorkloadPosition {
  const WorkloadPosition({required this.name, required this.count});

  factory WorkloadPosition.fromJson(Map<String, dynamic> json) {
    return WorkloadPosition(
      name: json['name'] as String,
      count: json['count'] as int,
    );
  }

  final String name;
  final int count;
}

class WorkloadMember {
  const WorkloadMember({
    required this.membershipId,
    required this.displayName,
    required this.scheduleCount,
    required this.assignmentCount,
    required this.positions,
    this.lastScheduledAt,
  });

  factory WorkloadMember.fromJson(Map<String, dynamic> json) {
    return WorkloadMember(
      membershipId: json['membershipId'] as String,
      displayName: json['displayName'] as String,
      scheduleCount: json['scheduleCount'] as int? ?? 0,
      assignmentCount: json['assignmentCount'] as int? ?? 0,
      lastScheduledAt: json['lastScheduledAt'] == null
          ? null
          : DateTime.parse(json['lastScheduledAt'] as String).toUtc(),
      positions: (json['positions'] as List<dynamic>? ?? const [])
          .map(
            (item) => WorkloadPosition.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String membershipId;
  final String displayName;
  final int scheduleCount;
  final int assignmentCount;
  final DateTime? lastScheduledAt;
  final List<WorkloadPosition> positions;
}

class WorkloadReport {
  const WorkloadReport({
    required this.weeks,
    required this.since,
    required this.until,
    required this.members,
  });

  factory WorkloadReport.fromJson(Map<String, dynamic> json) {
    return WorkloadReport(
      weeks: json['weeks'] as int,
      since: DateTime.parse(json['since'] as String).toUtc(),
      until: DateTime.parse(json['until'] as String).toUtc(),
      members: (json['members'] as List<dynamic>? ?? const [])
          .map((item) => WorkloadMember.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int weeks;
  final DateTime since;
  final DateTime until;
  final List<WorkloadMember> members;
}

/// Contexto de rodízio de uma pessoa, para o seletor da escalação.
///
/// É deliberadamente magro: o seletor precisa de duas frases curtas ao lado do
/// nome, não de um relatório. O relatório inteiro é [WorkloadReport], e ele
/// tem tela própria.
class RotationMember {
  const RotationMember({
    required this.membershipId,
    required this.recentCount,
    this.lastScheduledAt,
  });

  factory RotationMember.fromJson(Map<String, dynamic> json) {
    return RotationMember(
      membershipId: json['membershipId'] as String,
      recentCount: json['recentCount'] as int? ?? 0,
      lastScheduledAt: json['lastScheduledAt'] == null
          ? null
          : DateTime.parse(json['lastScheduledAt'] as String).toUtc(),
    );
  }

  final String membershipId;

  /// Escalas na janela recente. Conta escalas, e não funções: quem tocou
  /// baixo e cantou no mesmo domingo serviu uma vez.
  final int recentCount;

  /// Nulo = ninguém a escalou nos últimos 12 meses.
  final DateTime? lastScheduledAt;
}

class RotationReport {
  const RotationReport({required this.weeks, required this.members});

  factory RotationReport.fromJson(Map<String, dynamic> json) {
    return RotationReport(
      weeks: json['weeks'] as int? ?? 8,
      members: {
        for (final item in json['members'] as List<dynamic>? ?? const [])
          (item as Map<String, dynamic>)['membershipId'] as String:
              RotationMember.fromJson(item),
      },
    );
  }

  final int weeks;

  /// Indexado por `membershipId`: o seletor consulta pessoa por pessoa
  /// enquanto desenha a lista.
  final Map<String, RotationMember> members;
}
