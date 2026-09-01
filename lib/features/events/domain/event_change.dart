/// Uma linha do histórico da escala: quem mexeu, quando e no quê.
class EventChange {
  const EventChange({
    required this.id,
    required this.actorName,
    required this.kind,
    required this.summary,
    required this.createdAt,
  });

  factory EventChange.fromJson(Map<String, dynamic> json) {
    return EventChange(
      id: json['id'] as String,
      actorName: json['actorName'] as String? ?? 'Alguém',
      kind: json['kind'] as String? ?? 'DETAILS',
      summary: (json['summary'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
  }

  final String id;

  /// Nome de quem fez, congelado no momento da mudança: quem saiu da equipe
  /// depois continua respondendo pelo que fez enquanto estava nela.
  final String actorName;

  /// `CREATED`, `DETAILS`, `ASSIGNMENTS`, `SETLIST` ou `STATUS`.
  final String kind;

  /// Uma frase por mudança.
  final List<String> summary;
  final DateTime createdAt;
}
