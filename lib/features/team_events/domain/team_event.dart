/// Um compromisso da equipe que **não é escala**: reunião, ensaio geral,
/// churrasco, treinamento.
///
/// **Cuidado com o nome.** Na tela, a escala se chama "escala" e isto se chama
/// "evento" — mas no código `Event` continua sendo a **escala** (ver a seção de
/// vocabulário do AGENTS.md). Este é o `TeamEvent`.
///
/// Não tem culto, escalação, repertório, ministrante nem rascunho. O que ele
/// tem é o que um churrasco tem: nome, quando começa, talvez quando acaba,
/// onde, e um recado.
class TeamEvent {
  const TeamEvent({
    required this.id,
    required this.teamId,
    required this.title,
    required this.startsAt,
    required this.timezone,
    this.endsAt,
    this.location,
    this.notes,
  });

  factory TeamEvent.fromJson(Map<String, dynamic> json) {
    return TeamEvent(
      id: json['id'] as String,
      teamId: json['teamId'] as String? ?? '',
      title: json['title'] as String? ?? 'Evento',
      startsAt: DateTime.parse(json['startsAt'] as String).toUtc(),
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.parse(json['endsAt'] as String).toUtc(),
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
    );
  }

  final String id;
  final String teamId;

  /// Obrigatório, ao contrário do título da escala: "quinta, 17" não diz se é
  /// reunião de liderança ou churrasco.
  final String title;

  final DateTime startsAt;

  /// Quando acaba, **se** a liderança souber. Nulo é normal e comum — e a
  /// ausência é informação, não buraco: churrasco não tem hora para acabar.
  final DateTime? endsAt;

  final String? location;
  final String? notes;
  final String timezone;

  bool get hasLocation => location != null && location!.isNotEmpty;
  bool get hasNotes => notes != null && notes!.isNotEmpty;
}
