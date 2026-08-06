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
import '../../features/events/presentation/event_form_screen.dart';
import '../../features/events/presentation/main_shell.dart';
import '../../features/health/presentation/health_screen.dart';
import '../../features/invites/presentation/invites_screen.dart';
import '../../features/invites/presentation/join_team_screen.dart';
import '../../features/unavailability/presentation/my_unavailability_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/team/data/team_repository.dart';
import '../../features/team/domain/team_models.dart';
import '../../features/team/presentation/create_team_screen.dart';
import '../../features/team/presentation/member_form_screen.dart';
import '../../features/team/presentation/members_screen.dart';
import '../../features/team/presentation/service_templates_screen.dart';

/// Rotas acessiveis sem sessao.
const _publicRoutes = {'/login', '/cadastro', '/diagnostico'};

/// Enquanto a senha não for trocada, so estas rotas respondem -- espelha o que
/// o backend permite via @SkipPasswordChangeCheck.
const _passwordChangeRoutes = {'/trocar-senha', '/diagnostico'};

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

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;

      switch (status) {
        case AuthStatus.unknown:
          return location == '/' ? null : '/';

        case AuthStatus.unauthenticated:
          return _publicRoutes.contains(location) ? null : '/login';

        case AuthStatus.mustChangePassword:
          return _passwordChangeRoutes.contains(location)
              ? null
              : '/trocar-senha';

        case AuthStatus.authenticated:
          final isEntryRoute = location == '/' ||
              _publicRoutes.contains(location) ||
              location == '/trocar-senha';
          if (isEntryRoute && location != '/diagnostico') {
            return '/agenda';
          }
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
      GoRoute(
        path: '/equipe/nova',
        builder: (_, __) => const CreateTeamScreen(),
      ),
      GoRoute(path: '/convite', builder: (_, __) => const JoinTeamScreen()),
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
        builder: (_, __) =>
            _withActiveTeam(ref, (id) => ServiceTemplatesScreen(teamId: id)),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/agenda',
            builder: (_, __) => const AgendaScreen(),
            routes: [
              GoRoute(
                path: 'novo',
                builder: (_, __) => const EventFormScreen(),
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
                    path: 'escalar',
                    builder: (_, state) => AssignmentFormScreen(
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Perfil dentro da casca: é uma das abas, então precisa da barra.
          GoRoute(path: '/perfil', builder: (_, __) => const ProfileScreen()),
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
