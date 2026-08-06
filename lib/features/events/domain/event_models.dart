import '../../unavailability/domain/unavailability_models.dart';

class AssignmentMember {
  const AssignmentMember({
    required this.id,
    required this.membershipId,
    required this.displayName,
    required this.note,
    required this.isRegisteredForPosition,
  });

  factory AssignmentMember.fromJson(Map<String, dynamic> json) {
    return AssignmentMember(
      id: json['id'] as String,
      membershipId: json['membershipId'] as String,
      displayName: json['displayName'] as String,
      note: json['note'] as String?,
      isRegisteredForPosition:
          json['isRegisteredForPosition'] as bool? ?? true,
    );
  }

  final String id;
  final String membershipId;
  final String displayName;
  final String? note;
  final bool isRegisteredForPosition;
}

/// Quem conduz a ministração do louvor nesta escala.
///
/// Um por escala, não por função: é quem lê os versículos, fala antes das
/// músicas e delega. Está escalado em alguma função, mas o papel não pertence
/// à função.
class EventMinister {
  const EventMinister({required this.membershipId, required this.displayName});

  factory EventMinister.fromJson(Map<String, dynamic> json) {
    return EventMinister(
      membershipId: json['membershipId'] as String,
      displayName: json['displayName'] as String,
    );
  }

  final String membershipId;
  final String displayName;
}

class AssignmentGroup {
  const AssignmentGroup({
    required this.positionId,
    required this.positionName,
    required this.sortOrder,
    required this.members,
  });

  factory AssignmentGroup.fromJson(Map<String, dynamic> json) {
    return AssignmentGroup(
      positionId: json['positionId'] as String,
      positionName: json['positionName'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      members: (json['members'] as List<dynamic>? ?? const [])
          .map((e) => AssignmentMember.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String positionId;
  final String positionName;
  final int sortOrder;
  final List<AssignmentMember> members;
}

/// Um horário de culto dentro da escala do dia.
///
/// No domingo típico da equipe são dois — manhã e noite — com a mesma
/// escalação, o mesmo ensaio e o mesmo local. Por isso o culto é filho da
/// escala, e não uma escala própria.
class EventService {
  const EventService({
    required this.id,
    required this.label,
    required this.startsAt,
  });

  factory EventService.fromJson(Map<String, dynamic> json) {
    return EventService(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Culto',
      startsAt: DateTime.parse(json['startsAt'] as String).toUtc(),
    );
  }

  final String id;

  /// "Manhã", "Noite". Vem da grade da igreja, ou é digitado em culto avulso.
  final String label;

  final DateTime startsAt;
}

class SameDayConflict {
  const SameDayConflict({
    required this.membershipId,
    required this.displayName,
    required this.otherEventId,
    required this.otherEventTitle,
  });

  factory SameDayConflict.fromJson(Map<String, dynamic> json) {
    return SameDayConflict(
      membershipId: json['membershipId'] as String,
      displayName: json['displayName'] as String,
      otherEventId: json['otherEventId'] as String,
      otherEventTitle: json['otherEventTitle'] as String,
    );
  }

  final String membershipId;
  final String displayName;
  final String otherEventId;
  final String otherEventTitle;
}

class EventWarnings {
  const EventWarnings({
    this.sameDayConflicts = const [],
    this.unavailableAssigned = const [],
  });

  factory EventWarnings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EventWarnings();
    }

    return EventWarnings(
      sameDayConflicts: (json['sameDayConflicts'] as List<dynamic>? ?? const [])
          .map((e) => SameDayConflict.fromJson(e as Map<String, dynamic>))
          .toList(),
      unavailableAssigned:
          (json['unavailableAssigned'] as List<dynamic>? ?? const [])
              .map((e) => UnavailableMember.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  final List<SameDayConflict> sameDayConflicts;

  /// Gente escalada que já tinha avisado que não pode neste dia.
  final List<UnavailableMember> unavailableAssigned;
}

class Event {
  const Event({
    required this.id,
    required this.teamId,
    required this.title,
    required this.startsAt,
    required this.rehearsalAt,
    required this.location,
    required this.notes,
    required this.colorPalette,
    required this.status,
    required this.timezone,
    required this.assignments,
    required this.songs,
    this.services = const [],
    this.minister,
    this.unavailable = const [],
    this.warnings = const EventWarnings(),
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      title: json['title'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toUtc(),
      rehearsalAt: _parseUtcDateTime(json['rehearsalAt']),
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      colorPalette: json['colorPalette'] as String?,
      status: json['status'] as String,
      timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
      assignments: (json['assignments'] as List<dynamic>? ?? const [])
          .map((e) {
            if (e is! Map<String, dynamic>) {
              return null;
            }
            // Lista da agenda ainda devolve array vazio; detalhe traz grupos.
            if (!e.containsKey('positionId')) {
              return null;
            }
            return AssignmentGroup.fromJson(e);
          })
          .whereType<AssignmentGroup>()
          .toList(),
      services: (json['services'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EventService.fromJson)
          .toList(),
      minister: json['minister'] is Map<String, dynamic>
          ? EventMinister.fromJson(json['minister'] as Map<String, dynamic>)
          : null,
      songs: (json['songs'] as List<dynamic>? ?? const []).cast<Object?>(),
      unavailable: (json['unavailable'] as List<dynamic>? ?? const [])
          .map((e) => UnavailableMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      warnings: EventWarnings.fromJson(
        json['warnings'] as Map<String, dynamic>?,
      ),
    );
  }

  final String id;
  final String teamId;
  final String title;
  final DateTime startsAt;
  final DateTime? rehearsalAt;
  final String? location;
  final String? notes;
  final String? colorPalette;
  final String status;
  final String timezone;
  final List<AssignmentGroup> assignments;
  final List<Object?> songs;

  /// Horários de culto desta escala, do mais cedo para o mais tarde.
  final List<EventService> services;

  /// Quem conduz a ministração do louvor. Nulo enquanto ninguém foi escolhido.
  final EventMinister? minister;

  /// Os cultos para exibir.
  ///
  /// Cache antigo, gravado antes desta versão, não tem `services`. Em vez de
  /// mostrar a escala sem horário nenhum, cai no `startsAt` — que é justamente
  /// o horário do primeiro culto.
  List<EventService> get displayServices {
    if (services.isNotEmpty) return services;
    return [EventService(id: id, label: 'Culto', startsAt: startsAt)];
  }

  /// Quem avisou que não pode no dia desta escala.
  final List<UnavailableMember> unavailable;
  final EventWarnings warnings;

  /// Nomes das funções em que o membership aparece nesta escala.
  /// Quantas pessoas distintas estao escaladas. Quem acumula duas funcoes
  /// conta uma vez -- o numero responde "a escala esta montada?", nao
  /// "quantas linhas tem a escala".
  int get scheduledMemberCount {
    return <String>{
      for (final group in assignments)
        for (final member in group.members) member.membershipId,
    }.length;
  }

  List<String> positionsForMembership(String? membershipId) {
    if (membershipId == null || membershipId.isEmpty) {
      return const [];
    }

    return [
      for (final group in assignments)
        if (group.members.any((m) => m.membershipId == membershipId))
          group.positionName,
    ];
  }

  static DateTime? _parseUtcDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value as String).toUtc();
  }
}

/// Texto do destaque "onde eu apareco" no topo da escala.
String? youAssignmentLabel(List<String> positionNames) {
  if (positionNames.isEmpty) {
    return null;
  }

  return 'VOCÊ: ${positionNames.join(', ')}';
}
