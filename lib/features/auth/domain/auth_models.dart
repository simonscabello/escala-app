class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mustChangePassword,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final bool mustChangePassword;

  /// Caminho da foto relativo ao host da API ("/uploads/avatars/x.jpg"), ou
  /// null. Quem monta o endereco completo e o AppAvatar.
  final String? avatarUrl;

  /// Primeiro nome, usado nas saudacoes da interface.
  String get firstName => name.split(' ').first;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Resumo de uma equipe da qual o usuario participa. A Etapa 2 usa isto no
/// onboarding para decidir entre "criar equipe" e ir direto para a agenda.
class TeamSummary {
  const TeamSummary({
    required this.membershipId,
    required this.teamId,
    required this.name,
    required this.role,
    required this.displayName,
  });

  final String membershipId;
  final String teamId;
  final String name;
  final String role;
  final String displayName;

  bool get canManage => role == 'OWNER' || role == 'LEADER';

  factory TeamSummary.fromJson(Map<String, dynamic> json) {
    return TeamSummary(
      membershipId: json['membershipId'] as String,
      teamId: json['teamId'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      displayName: json['displayName'] as String,
    );
  }
}

class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
