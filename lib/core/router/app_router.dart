import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/assignments/presentation/assignment_form_screen.dart';
import '../../features/events/presentation/agenda_screen.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../features/events/presentation/event_history_screen.dart';
import '../../features/events/presentation/event_form_screen.dart';
import '../../features/events/presentation/main_shell.dart';
import '../../features/events/presentation/setlist_form_screen.dart';
import '../../features/events/domain/event_models.dart';
import '../../features/health/presentation/health_screen.dart';
import '../../features/invites/presentation/invites_screen.dart';
import '../../features/invites/presentation/join_team_screen.dart';
import '../../features/unavailability/presentation/my_unavailability_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/team/data/team_repository.dart';
import '../../features/team/domain/team_models.dart';
import '../../features/songs/domain/song_models.dart';
import '../../features/songs/presentation/add_song_screen.dart';
import '../../features/songs/presentation/song_detail_screen.dart';
import '../../features/songs/presentation/song_form_screen.dart';
import '../../features/songs/presentation/song_usage_screen.dart';
import '../../features/songs/presentation/songs_screen.dart';
import '../../features/team/presentation/create_team_screen.dart';
import '../../features/team/presentation/member_form_screen.dart';
import '../../features/team/presentation/manage_team_screen.dart';
import '../../features/team/presentation/members_screen.dart';
import '../../features/team/presentation/positions_screen.dart';
import '../../features/team/presentation/service_templates_screen.dart';
import '../../features/team/presentation/team_settings_screen.dart';
import '../../features/team/presentation/workload_report_screen.dart';
import '../../features/unavailability/presentation/team_unavailability_screen.dart';

/// `AAAA-MM-DD` da barra de endereço. Inválida ou ausente vira nulo: a tela
/// cai no seu próprio padrão em vez de abrir num dia que ninguém escolheu.
DateTime? _parseDate(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value);
}

/// Rotas acessiveis sem sessao.
const _publicRoutes = {'/login', '/cadastro', '/diagnostico'};

/// Enquanto a senha não for trocada, so estas rotas respondem -- espelha o que
/// o backend permite via @SkipPasswordChangeCheck.
const _passwordChangeRoutes = {'/trocar-senha', '/diagnostico'};

/// Onde a pessoa queria chegar antes de o app saber se ela tem sessão.
///
/// **Isto existe por causa do navegador.** No celular o app sempre abre em `/`
/// e a questão não aparece. Na Web, colar `.../#/agenda/<id>` ou apertar F5
/// dentro de uma escala entra direto por aquela rota — e naquele instante o
/// `AuthController` ainda está lendo o armazenamento, com `status` em
/// `unknown`. O redirect precisa mandar para a splash (senão a tela pisca antes
/// de sabermos se há sessão), e sem guardar o destino a pessoa era despejada
/// na agenda: o link compartilhado não levava a lugar nenhum.
///
/// Guardado fora do `GoRouter` de propósito — o redirect é uma função pura em
/// relação ao roteador, e este é o único estado que ela precisa carregar entre
/// duas execuções. Sobrevive ao login: quem abre o link sem sessão passa pelo
/// `/login` e cai no destino depois de entrar.
class _PendingLocation {
  String? value;

  /// Guarda só o que **é** um destino. Rota de entrada não é destino: guardá-la
  /// criaria um redirect de `/agenda` para `/agenda` a cada bootstrap.
  void remember(String location) {
    final path = Uri.parse(location).path;
    if (path == '/' ||
        _publicRoutes.contains(path) ||
        _passwordChangeRoutes.contains(path)) {
      return;
    }
    value = location;
  }

  String? take() {
    final pending = value;
    value = null;
    return pending;
  }
}

/// Faz o go_router reavaliar o redirect sempre que o estado de auth muda.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);
  final pending = _PendingLocation();

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;

      switch (status) {
        case AuthStatus.unknown:
          if (location == '/') return null;
          pending.remember(state.uri.toString());
          return '/';

        case AuthStatus.unauthenticated:
          if (_publicRoutes.contains(location)) return null;
          pending.remember(state.uri.toString());
          return '/login';

        case AuthStatus.mustChangePassword:
          return _passwordChangeRoutes.contains(location)
              ? null
              : '/trocar-senha';

        case AuthStatus.authenticated:
          final isEntryRoute = location == '/' ||
              _publicRoutes.contains(location) ||
              location == '/trocar-senha';
          if (isEntryRoute && location != '/diagnostico') {
            // O destino guardado tem prioridade sobre a agenda: é o link que a
            // pessoa abriu ou a página que ela recarregou.
            return pending.take() ?? '/agenda';
          }
          pending.value = null;
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/cadastro', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/trocar-senha',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(path: '/home', redirect: (_, __) => '/agenda'),
      GoRoute(path: '/diagnostico', builder: (_, __) => const HealthScreen()),
      // Fora da casca: as duas telas de quem ainda não tem equipe. Uma barra
      // lateral que lista "Repertório" e "Convites" para quem não faz parte de
      // equipe nenhuma seria uma promessa falsa.
      GoRoute(
        path: '/equipe/nova',
        builder: (_, __) => const CreateTeamScreen(),
      ),
      GoRoute(path: '/convite', builder: (_, __) => const JoinTeamScreen()),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          // As telas de configuração vêm **antes** de `/equipe` para preservar
          // a ordem de correspondência que o roteador já tinha.
          //
          // Elas entraram na casca por causa do desktop: com a barra lateral,
          // abrir "Repertório" ou "Convites" fazia a navegação sumir da tela.
          // No celular nada muda de lugar — a barra inferior continua saindo em
          // tudo que não é uma das três abas, que é a regra de `MainShell`.
          GoRoute(
            path: '/disponibilidade',
            builder: (_, __) => _withActiveTeam(
              ref,
              (id) => MyUnavailabilityScreen(teamId: id),
            ),
          ),
          GoRoute(
            path: '/equipe/convites',
            builder: (_, __) =>
                _withActiveTeam(ref, (id) => InvitesScreen(teamId: id)),
          ),
          GoRoute(
            path: '/equipe/cultos',
            builder: (_, __) => _withActiveTeam(
              ref,
              (id) => ServiceTemplatesScreen(teamId: id),
            ),
          ),
          GoRoute(
            path: '/equipe/gerenciar',
            builder: (_, __) =>
                _withActiveTeam(ref, (id) => ManageTeamScreen(teamId: id)),
          ),
          GoRoute(
            path: '/equipe/funcoes',
            builder: (_, __) =>
                _withActiveTeam(ref, (id) => PositionsScreen(teamId: id)),
          ),
          GoRoute(
            path: '/equipe/dados',
            builder: (_, __) =>
                _withActiveTeam(ref, (id) => TeamSettingsScreen(teamId: id)),
          ),
          GoRoute(
            path: '/equipe/indisponibilidade',
            builder: (_, __) => _withActiveTeam(
              ref,
              (id) => TeamUnavailabilityScreen(teamId: id),
            ),
          ),
          GoRoute(
            path: '/equipe/participacao',
            builder: (_, __) => _withActiveTeam(
              ref,
              (id) => WorkloadReportScreen(teamId: id),
            ),
          ),
          GoRoute(
            path: '/equipe/musicas',
            builder: (_, __) =>
                _withActiveTeam(ref, (id) => SongsScreen(teamId: id)),
            routes: [
              GoRoute(
                path: 'nova',
                builder: (_, __) =>
                    _withActiveTeam(ref, (id) => AddSongScreen(teamId: id)),
              ),
              // Antes de `:songId`, senão "uso" e "arquivadas" seriam lidos
              // como o id de uma música e a tela abriria em erro.
              GoRoute(
                path: 'uso',
                builder: (_, __) =>
                    _withActiveTeam(ref, (id) => SongUsageScreen(teamId: id)),
              ),
              GoRoute(
                path: 'arquivadas',
                builder: (_, __) => _withActiveTeam(
                  ref,
                  (id) => SongsScreen(teamId: id, archived: true),
                ),
              ),
              GoRoute(
                path: ':songId',
                builder: (_, state) => _withActiveTeam(
                  ref,
                  (id) => SongDetailScreen(
                    teamId: id,
                    songId: state.pathParameters['songId']!,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'editar',
                    builder: (_, state) => _withActiveTeam(
                      ref,
                      (id) => SongFormScreen(
                        teamId: id,
                        songId: state.pathParameters['songId']!,
                        song: state.extra as Song?,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/agenda',
            builder: (_, __) => const AgendaScreen(),
            routes: [
              GoRoute(
                path: 'novo',
                builder: (_, state) => EventFormScreen(
                  initialDate: _parseDate(state.uri.queryParameters['data']),
                ),
              ),
              GoRoute(
                path: ':eventId',
                builder: (_, state) => EventDetailScreen(
                  eventId: state.pathParameters['eventId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'editar',
                    builder: (_, state) => EventFormScreen(
                      eventId: state.pathParameters['eventId'],
                    ),
                  ),
                  GoRoute(
                    path: 'historico',
                    builder: (_, state) => EventHistoryScreen(
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'escalar',
                    builder: (_, state) => AssignmentFormScreen(
                      eventId: state.pathParameters['eventId']!,
                      // `?novo=1` só é posto por quem acabou de criar a
                      // escala: dali a tela emenda no repertório em vez de
                      // voltar. Na consulta, e não em `extra`, para o encadeamento
                      // sobreviver a um recarregamento da rota.
                      nextIsSetlist: state.uri.queryParameters['novo'] == '1',
                    ),
                  ),
                  GoRoute(
                    path: 'repertorio',
                    builder: (_, state) => _withActiveTeam(
                      ref,
                      (id) => SetlistFormScreen(
                        teamId: id,
                        eventId: state.pathParameters['eventId']!,
                        // A escala vem por `extra` para a tela abrir já com o
                        // repertório atual, sem uma segunda ida ao servidor.
                        // Vem nula quando o encadeamento da criação chega aqui
                        // por URL; aí a tela busca sozinha.
                        event: state.extra as Event?,
                        isNewSchedule: state.uri.queryParameters['novo'] == '1',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Perfil dentro da casca: é uma das abas, então precisa da barra.
          GoRoute(
            path: '/perfil',
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'dados',
                builder: (_, __) => const EditProfileScreen(),
              ),
              // Troca voluntária. A obrigatória continua em /trocar-senha, que
              // fica fora da casca porque o redirect prende o app nela.
              GoRoute(
                path: 'senha',
                builder: (_, __) => const ChangePasswordScreen(forced: false),
              ),
            ],
          ),
          GoRoute(
            path: '/equipe',
            builder: (_, __) =>
                _withActiveTeam(ref, (id) => MembersScreen(teamId: id)),
            routes: [
              GoRoute(
                path: 'membros/novo',
                builder: (_, __) =>
                    _withActiveTeam(ref, (id) => MemberFormScreen(teamId: id)),
              ),
              GoRoute(
                path: 'membros/editar',
                builder: (_, state) => _withActiveTeam(
                  ref,
                  (id) => MemberFormScreen(
                    teamId: id,
                    member: state.extra as Member?,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// As telas de equipe dependem da equipe ativa. Se ela ainda não carregou,
/// mostramos um aviso em vez de quebrar a navegacao.
Widget _withActiveTeam(Ref ref, Widget Function(String teamId) build) {
  final teamId = ref.read(activeTeamIdProvider);

  if (teamId == null) {
    return const Scaffold(
      body: Center(child: Text('Você ainda não faz parte de uma equipe.')),
    );
  }

  return build(teamId);
}
