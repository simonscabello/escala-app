import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/data/event_repository.dart';
import '../../home/domain/home_summary.dart';
import '../../team/data/team_repository.dart';
import '../data/onboarding_repository.dart';
import '../domain/member_tour.dart';
import '../domain/onboarding_models.dart';

enum TourPhase {
  /// Nada na tela.
  idle,

  /// As boas-vindas, com "Conhecer o Pauta" e "Agora não".
  welcome,

  /// Montando o caminho (a próxima escala ainda está chegando).
  preparing,

  /// Uma parada destacada.
  touring,

  /// "Tudo pronto!".
  finished,
}

class TourState {
  const TourState({
    this.phase = TourPhase.idle,
    this.steps = const [],
    this.index = 0,
    this.manual = false,
    this.origin,
  });

  final TourPhase phase;
  final List<TourStep> steps;
  final int index;

  /// Aberto pela Ajuda. **Rever não grava nada**: o registro no servidor
  /// responde "o app ainda deve oferecer?", e quem pediu para ver de novo já
  /// respondeu a isso antes.
  final bool manual;

  /// Onde a pessoa estava quando o tour começou. Pular devolve a pessoa para
  /// lá — quem abriu pela Ajuda volta para a Ajuda.
  final String? origin;

  bool get isActive => phase != TourPhase.idle;
  TourStep? get step =>
      phase == TourPhase.touring && index < steps.length ? steps[index] : null;
  bool get isFirst => index == 0;

  TourState copyWith({
    TourPhase? phase,
    List<TourStep>? steps,
    int? index,
    bool? manual,
    String? origin,
  }) {
    return TourState(
      phase: phase ?? this.phase,
      steps: steps ?? this.steps,
      index: index ?? this.index,
      manual: manual ?? this.manual,
      origin: origin ?? this.origin,
    );
  }
}

/// O estado do tour dos integrantes, de ponta a ponta.
///
/// Quem desenha é o `OnboardingTourHost`, que fica acima de todas as telas;
/// este controlador só decide em que parada se está e **o que fica
/// registrado** — e só registra quando o tour foi oferecido pelo app, nunca
/// quando a pessoa pediu para rever.
class TourController extends StateNotifier<TourState> {
  TourController(this._ref) : super(const TourState()) {
    // Sair da conta no meio do tour não pode deixar o escuro por cima da tela
    // de login — nem a próxima pessoa a entrar começar na parada 4.
    _ref.listen<AuthStatus>(
      authControllerProvider.select((auth) => auth.status),
      (_, status) {
        if (status != AuthStatus.authenticated) {
          _offeredFor = null;
          state = const TourState();
        }
      },
    );
  }

  final Ref _ref;

  /// A conta para quem as boas-vindas já apareceram nesta abertura do app.
  /// Evita reoferecer enquanto a resposta ainda está a caminho do servidor.
  String? _offeredFor;

  /// As boas-vindas, se ainda não apareceram nesta abertura.
  void offerWelcome() {
    final userId = _ref.read(authControllerProvider).user?.id;
    if (userId == null || state.isActive || _offeredFor == userId) return;
    _offeredFor = userId;
    state = const TourState(phase: TourPhase.welcome, origin: '/inicio');
  }

  /// "Agora não". Conta como pular: o tour continua na Ajuda.
  Future<void> declineWelcome() async {
    final manual = state.manual;
    state = const TourState();
    if (!manual) await _record(OnboardingOutcome.skipped);
  }

  /// Começa pela primeira parada — vindo das boas-vindas ou da Ajuda.
  Future<void> start({bool manual = false, String? origin}) async {
    final wasManual = manual || state.manual;
    final from = origin ?? state.origin ?? '/inicio';
    state = TourState(
      phase: TourPhase.preparing,
      manual: wasManual,
      origin: from,
    );

    final steps = memberTourSteps(
      MemberTourContext(
        nextScheduleId: await _nextScheduleId(),
        pushSupported: PushService.isSupported,
      ),
    );
    // Cancelado enquanto a escala chegava (saiu da conta, por exemplo).
    if (state.phase != TourPhase.preparing) return;

    state = state.copyWith(phase: TourPhase.touring, steps: steps, index: 0);
  }

  void next() {
    if (state.phase != TourPhase.touring) return;
    if (state.index >= state.steps.length - 1) {
      state = state.copyWith(phase: TourPhase.finished);
    } else {
      state = state.copyWith(index: state.index + 1);
    }
  }

  void back() {
    if (state.phase == TourPhase.finished) {
      state = state.copyWith(phase: TourPhase.touring);
      return;
    }
    if (state.phase != TourPhase.touring || state.index == 0) return;
    state = state.copyWith(index: state.index - 1);
  }

  /// Pular. Devolve para onde a pessoa estava quando o tour começou.
  Future<String?> skip() async {
    final origin = state.origin;
    final manual = state.manual;
    state = const TourState();
    if (!manual) await _record(OnboardingOutcome.skipped);
    return origin;
  }

  /// "Começar", na última tela.
  Future<void> finish() async {
    final manual = state.manual;
    state = const TourState();
    if (!manual) await _record(OnboardingOutcome.completed);
  }

  Future<void> _record(OnboardingOutcome outcome) async {
    await recordOnboardingOutcome(_ref, OnboardingFlows.member, outcome);
    _ref.invalidate(memberOnboardingDueProvider);
  }

  /// A próxima escala **em que a pessoa entra**, pela mesma leitura da Home.
  ///
  /// Mesma consulta e mesma chave de cache da Home, então vinda de lá ela já
  /// está pronta. Vinda da Ajuda pode precisar buscar — e não esperar para
  /// sempre: sem resposta em poucos segundos, o tour segue sem abrir escala.
  Future<String?> _nextScheduleId() async {
    final auth = _ref.read(authControllerProvider);
    final teamId = _ref.read(activeTeamIdProvider);
    final team = auth.teams.where((t) => t.teamId == teamId).firstOrNull;
    if (teamId == null || team == null) return null;

    final provider = eventsProvider((teamId, 'upcoming'));
    // Escutar, e não só ler: a consulta é `autoDispose`, e sem ninguém
    // olhando ela seria descartada antes de responder.
    final subscription = _ref.listen(provider, (_, __) {});
    try {
      final cached =
          await _ref.read(provider.future).timeout(const Duration(seconds: 5));
      return HomeSummary.of(
        cached.data,
        membershipId: team.membershipId,
        canManage: team.canManage,
        now: DateTime.now(),
      ).myNext?.id;
    } on Object {
      return null;
    } finally {
      subscription.close();
    }
  }
}

final tourControllerProvider =
    StateNotifierProvider<TourController, TourState>(TourController.new);
