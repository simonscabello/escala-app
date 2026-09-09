import '../../events/domain/event_datetime.dart';
import '../../events/domain/event_models.dart';

/// Quantas músicas a escala tem, ou `null` quando o app **não sabe**.
///
/// A listagem da agenda devolve `songs` vazio de propósito (carregar o
/// repertório de cada escala multiplicaria a resposta), e o que ela traz é o
/// `songCount` de cada culto. Cache gravado antes desse campo existir o traz
/// nulo — e ali "não sei" e "não tem" teriam a mesma cara.
///
/// **Sem saber, cala**: é a mesma regra de `Event.servicesWithoutSongs`. Zero é
/// uma resposta ("nenhuma música ainda"); nulo não é.
int? scheduleSongCount(Event event) {
  if (event.songs.isNotEmpty) return event.songs.length;

  var total = 0;
  for (final service in event.displayServices) {
    final count = service.songCount;
    if (count == null) return null;
    total += count;
  }
  return total;
}

/// Quantos dias faltam para a escala, contados em **dias civis** no fuso da
/// equipe.
///
/// Zero é hoje, um é amanhã. Pelo relógio a conta erraria o caso que mais
/// importa: um culto às 09:00 de amanhã está a menos de 24 horas de uma consulta
/// feita hoje às 20:00, e "faltam 0 dias" viraria "é hoje".
int daysUntilEvent(Event event, DateTime now) {
  final timezone =
      event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
  final scheduleDay = eventLocalTime(event.startsAt, timezone);
  final today = eventLocalTime(now.toUtc(), timezone);
  return DateTime(scheduleDay.year, scheduleDay.month, scheduleDay.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
}

/// O que um aviso da Home está dizendo.
///
/// O enum carrega o **fato**, não a frase: quem escreve o texto é a tela, que é
/// onde já vivem os formatadores de horário. Aqui fica só a decisão de qual
/// aviso nasce, que é o que vale a pena travar em teste.
enum HomeNoticeKind {
  /// Você toca hoje.
  scheduleToday,

  /// Você toca amanhã.
  scheduleTomorrow,

  /// (liderança) escalas em rascunho, que a equipe ainda não vê.
  pendingDrafts,

  /// (liderança) a próxima escala da equipe ainda não tem ninguém escalado.
  unstaffedSchedule,
}

/// Um aviso curto no pé da Home.
///
/// **Nada aqui é dado novo.** Todo aviso sai da mesma lista de escalas que a
/// tela já mostrou acima — é a leitura dela, não uma segunda requisição.
class HomeNotice {
  const HomeNotice({required this.kind, this.event, this.count = 0});

  final HomeNoticeKind kind;

  /// A escala de que o aviso fala, quando ele fala de uma.
  final Event? event;

  /// Quantas escalas o aviso conta, quando ele conta.
  final int count;

  /// A rota é uma **aba** da casca, e não uma tela empilhada.
  ///
  /// Muda o gesto de navegação: aba se troca com `go`, e empilhar a agenda
  /// sobre a Home deixaria a barra inferior acesa num lugar com a tela
  /// mostrando outro.
  bool get opensTab => kind == HomeNoticeKind.pendingDrafts;

  /// Para onde o toque leva. Sempre uma rota que já existe.
  String get route => switch (kind) {
        HomeNoticeKind.scheduleToday ||
        HomeNoticeKind.scheduleTomorrow =>
          '/agenda/${event!.id}',
        HomeNoticeKind.pendingDrafts => '/agenda',
        HomeNoticeKind.unstaffedSchedule => '/agenda/${event!.id}/escalar',
      };
}

/// A Home, lida a partir da agenda.
///
/// **Uma lista de escalas, quatro respostas.** A Home não busca nada que a
/// agenda já não busque: ela observa o mesmo `eventsProvider((teamId,
/// 'upcoming'))` — mesma chave, mesma resposta, nenhuma requisição a mais — e
/// derreteria em duplicação se cada bloco da tela fizesse a sua própria conta
/// em cima da lista. Aqui a conta é uma só, e é testável sem widget nenhum.
///
/// A diferença que dá razão à tela está em [myNext]: a agenda destaca a próxima
/// escala **da equipe**, e a Home destaca a próxima escala **em que você
/// entra**. Quase sempre são a mesma; quando não são, é justamente aí que a
/// pergunta "quando eu toco?" precisava de resposta.
class HomeSummary {
  const HomeSummary({
    required this.myNext,
    required this.myPositions,
    required this.myFollowing,
    required this.notices,
    required this.hasSchedules,
  });

  /// A próxima escala em que a pessoa está escalada, dentro do horizonte que a
  /// agenda carregou. Nula quando ela não aparece em nenhuma.
  final Event? myNext;

  /// As funções dela em [myNext]. Vazio quando não há [myNext].
  final List<String> myPositions;

  /// A escala seguinte a [myNext] -- **também sua**.
  ///
  /// Responde "e depois?" no fio que a manchete abriu. A pergunta é "quando eu
  /// toco de novo?", e não "o que a equipe faz depois": a segunda é a agenda
  /// que responde, e responder as duas aqui era ter a agenda em miniatura
  /// dentro da Home -- três linhas repetindo a aba do lado.
  final Event? myFollowing;

  final List<HomeNotice> notices;

  /// A equipe tem alguma escala à frente. Separa "você está livre" de "não há
  /// nada marcado" — duas situações que pedem frases diferentes.
  final bool hasSchedules;

  /// No máximo dois avisos.
  ///
  /// A Home fecha com um bloco discreto, não com uma caixa de entrada: o
  /// terceiro aviso não é lido, e o que ele faz é tirar peso dos dois primeiros.
  static const int maxNotices = 2;

  static HomeSummary of(
    List<Event> events, {
    required String membershipId,
    required bool canManage,
    required DateTime now,
  }) {
    // A lista já vem ordenada do servidor (a mais próxima primeiro) e é essa
    // ordem que faz "a primeira em que eu entro" ser "a próxima em que eu
    // entro". Reordenar aqui só criaria uma segunda verdade.
    final minhas = [
      for (final event in events)
        if (event.positionsForMembership(membershipId).isNotEmpty) event,
    ];
    final myNext = minhas.firstOrNull;

    return HomeSummary(
      myNext: myNext,
      myPositions: myNext?.positionsForMembership(membershipId) ?? const [],
      // A segunda em que eu entro, e não a segunda da equipe: a manchete abriu
      // o fio de "quando eu toco", e "e depois?" continua o mesmo fio.
      myFollowing: minhas.length > 1 ? minhas[1] : null,
      hasSchedules: events.isNotEmpty,
      notices: _notices(
        events,
        myNext: myNext,
        canManage: canManage,
        now: now,
      ),
    );
  }

  static List<HomeNotice> _notices(
    List<Event> events, {
    required Event? myNext,
    required bool canManage,
    required DateTime now,
  }) {
    final notices = <HomeNotice>[];

    // Primeiro o que é sobre a própria pessoa e tem hora marcada: "é hoje"
    // vale mais do que qualquer pendência da liderança.
    if (myNext != null) {
      final days = daysUntilEvent(myNext, now);
      if (days == 0) {
        notices.add(
          HomeNotice(kind: HomeNoticeKind.scheduleToday, event: myNext),
        );
      } else if (days == 1) {
        notices.add(
          HomeNotice(kind: HomeNoticeKind.scheduleTomorrow, event: myNext),
        );
      }
    }

    if (canManage) {
      // Rascunho não é visível para a equipe: só quem gerencia recebe a lista
      // com eles, e só para essa pessoa a contagem significa alguma coisa.
      final drafts = events.where((e) => e.isDraft).length;
      if (drafts > 0) {
        notices.add(
          HomeNotice(kind: HomeNoticeKind.pendingDrafts, count: drafts),
        );
      }

      final unstaffed = events.where((e) => e.assignments.isEmpty).firstOrNull;
      if (unstaffed != null) {
        notices.add(
          HomeNotice(
            kind: HomeNoticeKind.unstaffedSchedule,
            event: unstaffed,
          ),
        );
      }
    }

    return notices.take(maxNotices).toList();
  }
}
