import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

enum AuthStatus {
  /// Ainda verificando se ha sessao salva -- estado da splash.
  unknown,
  unauthenticated,

  /// Autenticado, mas obrigado a trocar a senha antes de usar o app
  /// (senha redefinida pelo líder -- regra 27).
  mustChangePassword,
  authenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.teams = const [],
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.signedOut() : this(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final AuthUser? user;
  final List<TeamSummary> teams;

  factory AuthState.signedIn(AuthUser user, [List<TeamSummary> teams = const []]) {
    return AuthState(
      status: user.mustChangePassword
          ? AuthStatus.mustChangePassword
          : AuthStatus.authenticated,
      user: user,
      teams: teams,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState.unknown()) {
    _ref.listen<int>(sessionExpiredProvider, (_, __) => _signOutLocally());
    bootstrap();
  }

  final Ref _ref;

  AuthRepository get _repository => _ref.read(authRepositoryProvider);
  TokenStorage get _storage => _ref.read(tokenStorageProvider);

  /// Chamado no start: se ha token salvo, valida com o servidor.
  /// O interceptor renova a sessao sozinho se o access token tiver expirado.
  Future<void> bootstrap() async {
    // Sem timeout de proposito: um timeout curto aqui derruba a sessao de quem
    // esta em aparelho lento (aconteceu -- 5s não bastavam no emulador). Uma
    // falha real do armazenamento vira excecao e cai no catch; esperar mais e
    // melhor do que deslogar quem tinha sessao valida.
    String? refreshToken;
    try {
      refreshToken = await _storage.readRefreshToken();
    } catch (_) {
      refreshToken = null;
    }

    if (refreshToken == null) {
      state = const AuthState.signedOut();
      return;
    }

    try {
      final me = await _repository.me();
      state = AuthState.signedIn(me.user, me.teams);
    } on ApiException {
      await _storage.clear();
      state = const AuthState.signedOut();
    }
  }

  Future<void> login({required String email, required String password}) async {
    final session = await _repository.login(email: email, password: password);
    await _applySession(session);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await _repository.register(
      name: name,
      email: email,
      password: password,
    );
    await _applySession(session);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _applySession(session);
  }

  /// Edicao dos proprios dados. Depois de mudar o nome recarrega as equipes:
  /// o backend acerta junto o nome exibido na equipe (quando ninguem o
  /// personalizou), e o menu do app mostra esse nome.
  Future<void> updateProfile({String? name, String? email}) async {
    final user = await _repository.updateProfile(name: name, email: email);
    _replaceUser(user);
    if (name != null) {
      unawaited(_loadTeams());
    }
  }

  Future<void> updateAvatar(String filePath) async {
    _replaceUser(await _repository.uploadAvatar(filePath));
  }

  Future<void> removeAvatar() async {
    _replaceUser(await _repository.removeAvatar());
  }

  void _replaceUser(AuthUser user) {
    if (mounted) {
      state = AuthState.signedIn(user, state.teams);
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken != null) {
      await _repository.logout(refreshToken);
    }
    await _signOutLocally();
  }

  Future<void> _applySession(Session session) async {
    await _storage.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    state = AuthState.signedIn(session.user);

    // Carrega as equipes em segundo plano: a navegacao não precisa esperar.
    if (!session.user.mustChangePassword) {
      unawaited(_loadTeams());
    }
  }

  /// Recarrega usuario e equipes. Chamado depois de criar equipe ou aceitar
  /// convite, para o app saber que o usuario deixou de estar "sem equipe".
  Future<void> reloadTeams() => _loadTeams();

  Future<void> _loadTeams() async {
    try {
      final me = await _repository.me();
      if (mounted) {
        state = AuthState.signedIn(me.user, me.teams);
      }
    } on ApiException {
      // A tela seguinte recarrega quando precisar.
    }
  }

  Future<void> _signOutLocally() async {
    await _storage.clear();
    if (mounted) {
      state = const AuthState.signedOut();
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
