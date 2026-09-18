/// Os pontos da interface que o tour sabe destacar.
///
/// Cada tela marca o seu com [TourTarget] (ver `tour_target.dart`), usando
/// estes nomes. Nome fora desta lista não é destacado por ninguém — por isso
/// eles moram juntos, e não como texto solto em cada tela.
abstract final class TourTargetIds {
  /// A manchete da Home: a minha próxima escala, ou o "livre por enquanto".
  static const homeNext = 'home.next';

  /// A seção "Músicas" do detalhe da escala.
  static const eventSongs = 'event.songs';

  /// O atalho "Minha disponibilidade" da Home.
  static const homeAvailability = 'home.availability';

  /// O botão "Escolher dias" de Minha disponibilidade.
  static const availabilityChoose = 'availability.choose';

  /// O calendário da Agenda.
  static const agendaCalendar = 'agenda.calendar';

  /// As linhas "Repertório" e "Sugestões" da aba Equipe.
  static const teamRepertoire = 'team.repertoire';
  static const teamSuggestions = 'team.suggestions';

  /// O interruptor "Avisos no celular" do Perfil (só existe no Android).
  static const profilePush = 'profile.push';
}

/// Uma parada do tour: para onde ir, o que destacar e o que dizer.
///
/// [route] é para onde o app navega antes de destacar — o tour anda pelo app
/// de verdade, em vez de mostrar desenhos dele. [target] nulo é um cartão no
/// meio da tela, sem destaque: é o que sobra quando o ponto não existe nesta
/// plataforma (o interruptor de avisos na Web).
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    this.route,
    this.target,
  });

  final String title;
  final String body;
  final String? route;
  final String? target;
}

/// O que o tour precisa saber da pessoa para escolher o caminho.
class MemberTourContext {
  const MemberTourContext({
    required this.nextScheduleId,
    required this.pushSupported,
  });

  /// A minha próxima escala. Nula quando a pessoa não está em nenhuma — e aí
  /// as músicas são explicadas a partir da manchete da Home, em vez de abrir
  /// uma escala que não é dela.
  final String? nextScheduleId;

  /// Se este aparelho recebe aviso. Na Web não recebe, e o Perfil nem mostra
  /// o interruptor — o tour não pode apontar para ele.
  final bool pushSupported;
}

/// O tour dos integrantes, na ordem em que a pessoa usa o app numa semana.
///
/// **Oito paradas, uma ideia cada.** Não é manual: ensina onde as coisas
/// ficam e para que servem, e o resto a pessoa descobre tocando. Os textos
/// seguem a regra dos avisos — curtos, sem termo técnico, e dizendo o que a
/// pessoa faz, não como o app funciona.
///
/// **Disponibilidade tem duas paradas**, e é a única: é o que o integrante
/// *faz* no app além de ler, é o que tem prazo, e a Home mostra só a porta —
/// a segunda parada mostra o botão lá dentro.
List<TourStep> memberTourSteps(MemberTourContext context) {
  final nextId = context.nextScheduleId;

  return [
    TourStep(
      route: '/inicio',
      target: TourTargetIds.homeNext,
      title: 'Sua próxima escala',
      body: nextId != null
          ? 'Aqui aparece a próxima vez que você vai servir: o dia, o horário, '
              'a sua função e o ensaio. Toque no cartão para ver a escala '
              'completa.'
          : 'Quando você for escalado, a escala aparece aqui, com o dia, o '
              'horário, a sua função e o ensaio.',
    ),
    if (nextId != null)
      TourStep(
        route: '/agenda/$nextId',
        target: TourTargetIds.eventSongs,
        title: 'Músicas da escala',
        body: 'Estas são as músicas para preparar. Toque em uma delas para ver '
            'a letra, a cifra, o vídeo e o tom combinado para esta escala.',
      )
    else
      const TourStep(
        route: '/inicio',
        target: TourTargetIds.homeNext,
        title: 'Músicas da escala',
        body: 'Dentro da escala ficam as músicas para preparar. Toque em uma '
            'delas para ver a letra, a cifra, o vídeo e o tom combinado.',
      ),
    const TourStep(
      route: '/inicio',
      target: TourTargetIds.homeAvailability,
      title: 'Informe sua disponibilidade',
      body: 'Avise os líderes sobre os dias em que você não pode servir. '
          'Manter isso atualizado ajuda na organização das próximas escalas.',
    ),
    const TourStep(
      route: '/disponibilidade',
      target: TourTargetIds.availabilityChoose,
      title: 'Marque os dias em que não pode',
      body: 'Toque em Escolher dias, marque no calendário e confirme. Se os '
          'planos mudarem, volte aqui e desmarque. Também dá para chegar aqui '
          'pelo Perfil.',
    ),
    const TourStep(
      route: '/agenda',
      target: TourTargetIds.agendaCalendar,
      title: 'Agenda da equipe',
      body: 'Os dias pintados têm compromisso: escalas, com o horário do '
          'ensaio, e eventos, como reuniões. Toque num dia para ver o que está '
          'marcado. Em Minhas escalas, só as suas.',
    ),
    const TourStep(
      route: '/equipe',
      target: TourTargetIds.teamRepertoire,
      title: 'Repertório',
      body: 'Todas as músicas da equipe. Busque pelo nome e abra uma música '
          'para ver a letra, a cifra, o tom e o vídeo.',
    ),
    const TourStep(
      route: '/equipe',
      target: TourTargetIds.teamSuggestions,
      title: 'Sugira uma música',
      body: 'Em Sugestões, toque em Sugerir, escolha a música e conte por que '
          'ela faria bem à equipe. Os líderes respondem, e você acompanha por '
          'aqui.',
    ),
    if (context.pushSupported)
      const TourStep(
        route: '/perfil',
        target: TourTargetIds.profilePush,
        title: 'Avisos no celular',
        body: 'O Pauta avisa quando você é escalado, quando a escala ou as '
            'músicas mudam e quando sua sugestão é respondida. Também lembra '
            'do ensaio e do dia de servir. Deixe ligado.',
      )
    else
      const TourStep(
        title: 'Avisos no celular',
        body: 'No aplicativo para Android, o Pauta avisa quando você é '
            'escalado, quando a escala ou as músicas mudam e quando sua '
            'sugestão é respondida. Também lembra do ensaio e do dia de '
            'servir.',
      ),
  ];
}
