class Invite {
  const Invite({
    required this.id,
    required this.code,
    required this.formattedCode,
    required this.expiresAt,
    this.url,
    this.forMembershipId,
    this.forName,
    this.maxUses,
    this.uses = 0,
  });

  final String id;
  final String code;

  /// Código em grupos de 5, para ler e digitar sem erro.
  final String formattedCode;
  final DateTime expiresAt;

  /// Nulo enquanto não houver uma pagina publica hospedada (ver INVITE_BASE_URL).
  final String? url;

  /// Preenchido no convite individual: quem aceitar assume este cadastro.
  final String? forMembershipId;
  final String? forName;
  final int? maxUses;
  final int uses;

  bool get isIndividual => forMembershipId != null;

  factory Invite.fromJson(Map<String, dynamic> json) {
    return Invite(
      id: json['id'] as String,
      code: json['code'] as String,
      formattedCode: json['formattedCode'] as String? ?? json['code'] as String,
      url: json['url'] as String?,
      forMembershipId: json['forMembershipId'] as String?,
      forName: json['forName'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      maxUses: json['maxUses'] as int?,
      uses: json['uses'] as int? ?? 0,
    );
  }
}

/// O que a pessoa ve antes de entrar na equipe.
class InvitePreview {
  const InvitePreview({
    required this.teamName,
    this.invitedBy,
    this.invitedName,
  });

  final String teamName;
  final String? invitedBy;

  /// Preenchido no convite individual.
  final String? invitedName;

  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    return InvitePreview(
      teamName: json['teamName'] as String,
      invitedBy: json['invitedBy'] as String?,
      invitedName: json['invitedName'] as String?,
    );
  }
}

class AcceptedInvite {
  const AcceptedInvite({
    required this.teamName,
    required this.displayName,
    required this.joined,
  });

  final String teamName;
  final String displayName;

  /// false = a pessoa ja fazia parte da equipe.
  final bool joined;

  factory AcceptedInvite.fromJson(Map<String, dynamic> json) {
    return AcceptedInvite(
      teamName: json['teamName'] as String,
      displayName: json['displayName'] as String,
      joined: json['joined'] as bool? ?? true,
    );
  }
}
