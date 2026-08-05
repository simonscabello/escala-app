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
  const EventWarnings({this.sameDayConflicts = const []});

  factory EventWarnings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EventWarnings();
    }

    return EventWarnings(
      sameDayConflicts: (json['sameDayConflicts'] as List<dynamic>? ?? const [])
          .map((e) => SameDayConflict.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<SameDayConflict> sameDayConflicts;
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
      songs: (json['songs'] as List<dynamic>? ?? const []).cast<Object?>(),
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
  final EventWarnings warnings;

  /// Nomes das funções em que o membership aparece nesta escala.
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
