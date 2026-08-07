class Position {
  const Position({
    required this.id,
    required this.name,
    required this.category,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String category;
  final int sortOrder;
  final bool isActive;

  bool get isVocal => category == 'VOCAL';
  bool get isInstrument => category == 'INSTRUMENT';

  /// Multimídia e som: apoio ao culto, fora da banda.
  bool get isTech => category == 'TECH';

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class Member {
  const Member({
    required this.id,
    required this.displayName,
    required this.role,
    required this.hasAccount,
    this.isGuest = false,
    required this.positions,
    this.phone,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String role;

  /// false = cadastrado pelo líder, ainda sem conta no app.
  final bool hasAccount;

  /// Músico de fora, convidado para uma ocasião. Não é integrante da equipe.
  final bool isGuest;
  final List<Position> positions;
  final String? phone;
  final String? email;

  /// Foto da conta, quando o integrante tem uma. Membro sem conta cai na
  /// inicial do nome.
  final String? avatarUrl;

  bool get isOwner => role == 'OWNER';
  bool get canManage => role == 'OWNER' || role == 'LEADER';

  String get roleLabel => switch (role) {
        'OWNER' => 'Dono',
        'LEADER' => 'Líder',
        _ => 'Membro',
      };

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      hasAccount: json['hasAccount'] as bool? ?? false,
      isGuest: json['isGuest'] as bool? ?? false,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      positions: (json['positions'] as List<dynamic>? ?? [])
          .map((e) => Position.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.timezone,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String timezone;
  final int memberCount;

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
      memberCount: json['memberCount'] as int? ?? 0,
    );
  }
}
