import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/events/domain/schedule_share_text.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });

  Event sampleEvent({List<Object?> songs = const []}) {
    return Event.fromJson({
      'id': 'e1',
      'teamId': 't1',
      'title': 'Culto da Manhã',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'rehearsalAt': '2026-08-15T22:00:00.000Z',
      'location': 'Templo',
      'notes': 'Chegar cedo',
      'colorPalette': 'Preto e dourado',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': [
        {
          'positionId': 'p1',
          'positionName': 'Guitarra',
          'sortOrder': 1,
          'members': [
            {
              'id': 'a1',
              'membershipId': 'm1',
              'displayName': 'Samuel',
              'note': null,
              'isRegisteredForPosition': true,
            },
          ],
        },
      ],
      'songs': songs,
    });
  }

  test('texto de compartilhamento inclui culto, ensaio e equipe', () {
    final text = buildScheduleShareText(sampleEvent());

    expect(text, contains('Culto da Manhã'));
    expect(text, contains('Culto às 09:00'));
    expect(text, contains('Ensaio:'));
    expect(text, contains('Guitarra:'));
    expect(text, contains('• Samuel'));
    expect(text, contains('Paleta: Preto e dourado'));
    expect(text, contains('Observações'));
    expect(text, contains('Chegar cedo'));
    expect(text, isNot(contains('Músicas')));
  });

  test('domingo com dois cultos lista os dois horários', () {
    final event = Event.fromJson({
      'id': 'e2',
      'teamId': 't1',
      'title': 'Domingo',
      // A escala começa no culto mais cedo; os horários vêm de services.
      'startsAt': '2026-08-16T11:30:00.000Z',
      // Ensaio ENTRE os dois cultos: 13:00, "após a EBD".
      'rehearsalAt': '2026-08-16T16:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'services': [
        {'id': 's1', 'label': 'Manhã', 'startsAt': '2026-08-16T11:30:00.000Z'},
        {'id': 's2', 'label': 'Noite', 'startsAt': '2026-08-16T22:00:00.000Z'},
      ],
      'assignments': [],
      'songs': [],
    });

    final text = buildScheduleShareText(event);

    expect(text, contains('Manhã às 08:30'));
    expect(text, contains('Noite às 19:00'));
    // A equipe é uma só para os dois cultos: nada de repetir a escalação.
    expect('Manhã'.allMatches(text).length, 1);
  });

  test('ministrante aparece antes da equipe', () {
    final event = Event.fromJson({
      'id': 'e4',
      'teamId': 't1',
      'title': 'Domingo',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'minister': {'membershipId': 'm1', 'displayName': 'Ana'},
      'assignments': [],
      'songs': [],
    });

    final text = buildScheduleShareText(event);

    expect(text, contains('Ministrante: Ana'));
    expect(text.indexOf('Ministrante'), lessThan(text.indexOf('Equipe')));
  });

  test('sem ministrante escolhido, a linha não aparece', () {
    final event = Event.fromJson({
      'id': 'e5',
      'teamId': 't1',
      'title': 'Domingo',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': [],
      'songs': [],
    });

    expect(event.minister, isNull);
    expect(buildScheduleShareText(event), isNot(contains('Ministrante')));
  });

  test('escala sem services (cache antigo) cai no horário da escala', () {
    final event = Event.fromJson({
      'id': 'e3',
      'teamId': 't1',
      'title': 'Escala antiga',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': [],
      'songs': [],
    });

    expect(event.services, isEmpty);
    expect(event.displayServices, hasLength(1));
    expect(buildScheduleShareText(event), contains('Culto às 09:00'));
  });

  test('texto inclui músicas quando a lista não está vazia', () {
    final text = buildScheduleShareText(
      sampleEvent(
        songs: [
          // Formato que a API devolve: o `key` já vem resolvido pelo
          // servidor -- o desta escala quando existe, senão o da equipe.
          {
            'songId': 's1',
            'title': 'Grande é o Senhor',
            'artist': 'Adoração',
            'key': 'G',
            'keyOverride': 'G',
            'defaultKey': 'E',
          },
          {
            'songId': 's2',
            'title': 'Aclame ao Senhor',
            'artist': 'Diante do Trono',
            'key': 'A',
            'defaultKey': 'A',
          },
        ],
      ),
    );

    expect(text, contains('Músicas'));
    // Numeradas: a ordem do repertório é o que a equipe vai tocar.
    expect(text, contains('1. Grande é o Senhor — Adoração (G)'));
    expect(text, contains('2. Aclame ao Senhor — Diante do Trono (A)'));
  });

  test('música sem tom não ganha parênteses vazios', () {
    final text = buildScheduleShareText(
      sampleEvent(
        songs: [
          {'songId': 's1', 'title': 'Corinho da igreja'},
        ],
      ),
    );

    expect(text, contains('1. Corinho da igreja'));
    expect(text, isNot(contains('()')));
  });

  /// Escala de domingo com manhã e noite, cada culto com o próprio repertório.
  Event doisCultos({required List<Object?> songs}) {
    return Event.fromJson({
      'id': 'e6',
      'teamId': 't1',
      'startsAt': '2026-08-16T11:30:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'services': [
        {'id': 's-manha', 'label': 'Manhã', 'startsAt': '2026-08-16T11:30:00.000Z'},
        {'id': 's-noite', 'label': 'Noite', 'startsAt': '2026-08-16T22:00:00.000Z'},
      ],
      'assignments': [],
      'songs': songs,
    });
  }

  test('com um culto só, o repertório não ganha cabeçalho de culto', () {
    final text = buildScheduleShareText(
      sampleEvent(
        songs: [
          {'songId': 's1', 'serviceId': 'x', 'title': 'Uma Canção', 'key': 'G'},
        ],
      ),
    );

    expect(text, contains('🎶 Músicas'));
    expect(text, contains('1. Uma Canção (G)'));
    // O horário já está na linha "Culto às 09:00" lá em cima; repeti-lo
    // sobre a única lista seria ruído numa mensagem lida no celular.
    expect('Culto às 09:00'.allMatches(text).length, 1);
    expect(text, isNot(contains('Culto 09:00')));
  });

  test('com dois cultos, cada um ganha sua seção e sua numeração', () {
    final text = buildScheduleShareText(
      doisCultos(
        songs: [
          {'songId': 's1', 'serviceId': 's-manha', 'title': 'Abre Manhã'},
          {'songId': 's2', 'serviceId': 's-manha', 'title': 'Segue Manhã'},
          {'songId': 's3', 'serviceId': 's-noite', 'title': 'Abre Noite'},
          // A mesma música da manhã, à noite em outro tom: duas linhas, e é
          // assim que a equipe realmente monta o domingo.
          {
            'songId': 's1',
            'serviceId': 's-noite',
            'title': 'Abre Manhã',
            'key': 'Bm',
          },
        ],
      ),
    );

    expect(text, contains('Manhã 08:30'));
    expect(text, contains('Noite 19:00'));
    // A numeração recomeça: "a 2ª da noite" é como a equipe fala.
    expect(text, contains('1. Abre Manhã\n2. Segue Manhã'));
    expect(text, contains('1. Abre Noite\n2. Abre Manhã (Bm)'));
  });

  test('culto sem música não vira seção vazia no texto', () {
    final text = buildScheduleShareText(
      doisCultos(
        songs: [
          {'songId': 's1', 'serviceId': 's-manha', 'title': 'Só de Manhã'},
        ],
      ),
    );

    expect(text, contains('1. Só de Manhã'));
    // Com um único culto tendo repertório, o cabeçalho não entra -- e a noite
    // não aparece como uma seção vazia, que só ocuparia linha.
    expect(text, isNot(contains('Noite 19:00')));
    expect(text, isNot(contains('Manhã 08:30')));
  });

  test('repertório agrupado por culto, com o culto vazio preservado', () {
    final event = doisCultos(
      songs: [
        {'songId': 's1', 'serviceId': 's-noite', 'title': 'Da Noite'},
      ],
    );

    final grupos = event.songsByService;

    expect(grupos, hasLength(2));
    expect(grupos[0].service.label, 'Manhã');
    // O culto vazio continua na lista: é o que faz a tela mostrar o que falta
    // montar, em vez de esconder o buraco.
    expect(grupos[0].songs, isEmpty);
    expect(grupos[1].service.label, 'Noite');
    expect(grupos[1].songs.single.title, 'Da Noite');
  });

  test('música de cache antigo, sem serviceId, cai no primeiro culto', () {
    final event = doisCultos(
      songs: [
        {'songId': 's1', 'title': 'Gravada antes desta versão'},
      ],
    );

    expect(event.songs.single.serviceId, isEmpty);
    // Onde ela estava antes de os cultos terem repertório próprio.
    expect(
      event.songsByService[0].songs.single.title,
      'Gravada antes desta versão',
    );
    expect(event.songsByService[1].songs, isEmpty);
  });

  test('emoji marca seção, nunca linha que se repete', () {
    // Dois cultos e duas funções: é o caso que mais multiplicava marcador na
    // versão anterior, que punha um em cada horário e um em cada função.
    final text = buildScheduleShareText(
      Event.fromJson({
        'id': 'e1',
        'teamId': 't1',
        'startsAt': '2026-08-09T12:00:00.000Z',
        'rehearsalAt': '2026-08-08T22:00:00.000Z',
        'location': 'Templo',
        'notes': 'Chegar 30 min antes',
        'timezone': 'America/Sao_Paulo',
        'status': 'PUBLISHED',
        'minister': {'membershipId': 'm1', 'displayName': 'Samuel'},
        'services': [
          {
            'id': 'sv1',
            'label': 'Manhã',
            'startsAt': '2026-08-09T11:30:00.000Z',
          },
          {
            'id': 'sv2',
            'label': 'Noite',
            'startsAt': '2026-08-09T22:00:00.000Z',
          },
        ],
        'assignments': [
          {
            'positionId': 'p1',
            'positionName': 'Vocal',
            'sortOrder': 1,
            'members': [
              {
                'id': 'a1',
                'membershipId': 'm1',
                'displayName': 'Samuel',
                'isRegisteredForPosition': true,
              },
              {
                'id': 'a2',
                'membershipId': 'm2',
                'displayName': 'Maria',
                'isRegisteredForPosition': true,
              },
            ],
          },
          {
            'positionId': 'p2',
            'positionName': 'Violão',
            'sortOrder': 2,
            'members': [
              {
                'id': 'a3',
                'membershipId': 'm3',
                'displayName': 'João',
                'isRegisteredForPosition': true,
              },
            ],
          },
        ],
        'songs': [
          {'songId': 's1', 'serviceId': 'sv1', 'title': 'Primeira'},
          {'songId': 's2', 'serviceId': 'sv2', 'title': 'Segunda'},
        ],
      }),
    );

    final emojis = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
      unicode: true,
    ).allMatches(text).length;

    // Três: Equipe, Músicas e Observações. Se este número subir, alguém voltou
    // a marcar linha em vez de seção — que é exatamente o que tinha deixado a
    // mensagem poluída.
    expect(emojis, 3, reason: 'texto gerado:\n$text');
  });
}
