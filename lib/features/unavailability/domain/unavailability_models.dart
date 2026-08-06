/// Um dia em que o integrante avisou que não pode ser escalado.
class Unavailability {
  const Unavailability({
    required this.id,
    required this.membershipId,
    required this.date,
    this.displayName,
    this.reason,
  });

  final String id;
  final String membershipId;

  /// Dia civil, sem hora — vem do backend como AAAA-MM-DD.
  final DateTime date;
  final String? displayName;
  final String? reason;

  factory Unavailability.fromJson(Map<String, dynamic> json) {
    final raw = json['date'] as String;
    final parts = raw.split('-').map(int.parse).toList();

    return Unavailability(
      id: json['id'] as String,
      membershipId: json['membershipId'] as String,
      // Sem UTC nem fuso: é uma data de calendário, não um instante.
      date: DateTime(parts[0], parts[1], parts[2]),
      displayName: json['displayName'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

/// Quem está indisponível em uma escala específica, como o backend devolve
/// junto do detalhe.
class UnavailableMember {
  const UnavailableMember({
    required this.membershipId,
    required this.displayName,
    this.reason,
  });

  final String membershipId;
  final String displayName;
  final String? reason;

  factory UnavailableMember.fromJson(Map<String, dynamic> json) {
    return UnavailableMember(
      membershipId: json['membershipId'] as String,
      displayName: json['displayName'] as String? ?? '',
      reason: json['reason'] as String?,
    );
  }
}
