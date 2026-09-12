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

  test('texto de compartilhamento abre pelo cabeçalho, data e equipe', () {
    final text = buildScheduleShareText(sampleEvent());

    expect(text, startsWith('*Escala de Louvor*\n'));
    expect(text, contains('*Culto da Manhã*'));
    expect(text, contains('*Domingo, 16 de agosto*'));
    expect(text, contains('*Equipe*'));
    expect(text, contains('*Guitarra:* Samuel'));
    expect(text, contains('*Roupas:* Preto e dourado'));
    expect(text, contains('*Observações*'));
    expect(text, contains('Chegar cedo'));
    // A seção entra mesmo vazia: escala publicada sem repertório é caso
    // normal, e sumir com ela deixaria quem recebe sem saber se as músicas
    // não saíram ou se o texto veio pela metade.
    expect(text, contains('*Músicas*'));
    expect(text, contains('Ainda não escolhidas.'));
  });

  test('horários de culto e de ensaio não vão na mensagem', () {
    // Ambos existem na escala de exemplo: o culto às 09:00 e o ensaio no
    // sábado às 19:00. Quem recebe o texto já sabe a que horas a igreja abre,
    // e as duas linhas empurravam o repertório para fora da primeira tela.
    final text = buildScheduleShareText(sampleEvent());

    expect(text, isNot(contains('09:00')));
    expect(text, isNot(contains('19:00')));
    expect(text, isNot(contains('Ensaio')));
    expect(text, isNot(contains('Sem ensaio')));
  });

  test('domingo com dois cultos não repete a equipe nem lista horário', () {
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

    expect(text, isNot(contains('08:30')));
    expect(text, isNot(contains('19:00')));
    // Sem repertório em culto nenhum, os dois rótulos não entram: seria dizer
    // duas vezes a mesma coisa.
    expect('Manhã'.allMatches(text).length, 0);
  });

  test('quem ministra aparece dentro do Vocal, e não em linha própria', () {
    final event = Event.fromJson({
      'id': 'e4',
      'teamId': 't1',
      'title': 'Domingo',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'minister': {'membershipId': 'm2', 'displayName': 'Joseane Alves'},
      'assignments': [
        {
          'positionId': 'p1',
          'positionName': 'Vocal',
          'sortOrder': 1,
          'members': [
            {
              'id': 'a1',
              'membershipId': 'm1',
              'displayName': 'Gisely Ramos',
              'isRegisteredForPosition': true,
            },
            {
              'id': 'a2',
              'membershipId': 'm2',
              'displayName': 'Joseane Alves',
              'isRegisteredForPosition': true,
            },
          ],
        },
      ],
      'songs': [],
    });

    final text = buildScheduleShareText(event);

    expect(text, contains('*Vocal:* Gisely e Joseane *(Ministrante)*'));
    // A linha separada some: repetia o nome duas vezes na mesma mensagem e
    // fazia parecer que eram duas pessoas.
    expect(text, isNot(contains('*Ministrante:*')));
    expect('Joseane'.allMatches(text).length, 1);
  });

  test('quem só conduz, sem função, mantém a linha de ministrante', () {
    // A regra é não repetir o nome, não escondê-lo: sem nenhuma função, sumir
    // com a linha deixaria a mensagem sem dizer a quem a equipe se reporta.
    final event = Event.fromJson({
      'id': 'e4b',
      'teamId': 't1',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'minister': {'membershipId': 'm9', 'displayName': 'Ana Clara Souza'},
      'assignments': [
        {
          'positionId': 'p1',
          'positionName': 'Violão',
          'sortOrder': 1,
          'members': [
            {
              'id': 'a1',
              'membershipId': 'm1',
              'displayName': 'Gerson',
              'isRegisteredForPosition': true,
            },
          ],
        },
      ],
      'songs': [],
    });

    expect(buildScheduleShareText(event), contains('*Ministrante:* Ana'));
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

  group('só o primeiro nome', () {
    Event comVocal(List<Map<String, Object?>> membros) {
      return Event.fromJson({
        'id': 'e-nomes',
        'teamId': 't1',
        'startsAt': '2026-08-16T12:00:00.000Z',
        'status': 'PUBLISHED',
        'timezone': 'America/Sao_Paulo',
        'assignments': [
          {
            'positionId': 'p1',
            'positionName': 'Vocal',
            'sortOrder': 1,
            'members': [
              for (final membro in membros)
                {...membro, 'isRegisteredForPosition': true},
            ],
          },
        ],
        'songs': [],
      });
    }

    test('sem ambiguidade, o sobrenome não entra', () {
      final text = buildScheduleShareText(
        comVocal([
          {'id': 'a1', 'membershipId': 'm1', 'displayName': 'Gisely Ramos'},
          {'id': 'a2', 'membershipId': 'm2', 'displayName': 'Simon Pereira'},
        ]),
      );

      expect(text, contains('*Vocal:* Gisely e Simon'));
      expect(text, isNot(contains('Ramos')));
    });

    test('dois com o mesmo primeiro nome ganham a parte que os separa', () {
      final text = buildScheduleShareText(
        comVocal([
          {'id': 'a1', 'membershipId': 'm1', 'displayName': 'Simon Lopes'},
          {'id': 'a2', 'membershipId': 'm2', 'displayName': 'simon pedro'},
          {'id': 'a3', 'membershipId': 'm3', 'displayName': 'Larissa'},
        ]),
      );

      // A comparação ignora a caixa: "simon pedro" digitado em minúscula é o
      // mesmo primeiro nome de "Simon Lopes".
      expect(text, contains('Simon Lopes'));
      expect(text, contains('simon pedro'));
      // Quem não colide continua curto.
      expect(text, contains('e Larissa'));
    });

    test('nomes iguais até o fim vão inteiros, sem laço infinito', () {
      final text = buildScheduleShareText(
        comVocal([
          {'id': 'a1', 'membershipId': 'm1', 'displayName': 'João Silva'},
          {'id': 'a2', 'membershipId': 'm2', 'displayName': 'João Silva'},
        ]),
      );

      expect(text, contains('*Vocal:* João Silva e João Silva'));
    });

    test('a mesma pessoa em duas funções sai curta nas duas', () {
      final event = Event.fromJson({
        'id': 'e-duas',
        'teamId': 't1',
        'startsAt': '2026-08-16T12:00:00.000Z',
        'status': 'PUBLISHED',
        'timezone': 'America/Sao_Paulo',
        'assignments': [
          {
            'positionId': 'p1',
            'positionName': 'Vocal',
            'sortOrder': 1,
            'members': [
              {
                'id': 'a1',
                'membershipId': 'm1',
                'displayName': 'Simon Pereira',
                'isRegisteredForPosition': true,
              },
            ],
          },
          {
            'positionId': 'p2',
            'positionName': 'Teclado',
            'sortOrder': 2,
            'members': [
              {
                'id': 'a2',
                'membershipId': 'm1',
                'displayName': 'Simon Pereira',
                'isRegisteredForPosition': true,
              },
            ],
          },
        ],
        'songs': [],
      });

      final text = buildScheduleShareText(event);

      expect(text, contains('*Vocal:* Simon\n'));
      expect(text, contains('*Teclado:* Simon\n'));
    });
  });

  test('três ou mais na mesma função saem em lista com "e" no fim', () {
    final event = Event.fromJson({
      'id': 'e-lista',
      'teamId': 't1',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': [
        {
          'positionId': 'p1',
          'positionName': 'Vocal',
          'sortOrder': 1,
          'members': [
            for (final nome in ['Gisely', 'Joseane', 'Simon'])
              {
                'id': 'a-$nome',
                'membershipId': 'm-$nome',
                'displayName': nome,
                'isRegisteredForPosition': true,
              },
          ],
        },
      ],
      'songs': [],
    });

    expect(
      buildScheduleShareText(event),
      contains('*Vocal:* Gisely, Joseane e Simon'),
    );
  });

  test('escala sem services (cache antigo) não inventa horário', () {
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
    expect(buildScheduleShareText(event), isNot(contains('Culto às')));
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

    expect(text, contains('*Músicas*'));
    // Numeradas: a ordem do repertório é o que a equipe vai tocar.
    expect(text, contains('1. Grande é o Senhor\n'));
    expect(text, contains('2. Aclame ao Senhor\n'));
    // Nem artista nem tom: o tom está na cifra que cada um já abre, e os dois
    // juntos custavam meia linha por música.
    expect(text, isNot(contains('Adoração')));
    expect(text, isNot(contains('(G)')));
  });

  test('música nova sai marcada, e só ela', () {
    final text = buildScheduleShareText(
      sampleEvent(
        songs: [
          {
            'songId': 's1',
            'title': 'Bondade de Deus',
            'artist': 'Isaias Saad',
            'key': 'G',
            'isNew': true,
          },
          {'songId': 's2', 'title': 'Aclame ao Senhor', 'key': 'A'},
        ],
      ),
    );

    expect(text, contains('1. Bondade de Deus — *Nova*'));
    // Só a marcada: a etiqueta perde o sentido se aparecer em todas.
    expect(text, contains('2. Aclame ao Senhor\n'));
    expect('*Nova*'.allMatches(text).length, 1);
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
        {
          'id': 's-manha',
          'label': 'Manhã',
          'startsAt': '2026-08-16T11:30:00.000Z',
        },
        {
          'id': 's-noite',
          'label': 'Noite',
          'startsAt': '2026-08-16T22:00:00.000Z',
        },
      ],
      'assignments': [],
      'songs': songs,
    });
  }

  test('com um culto só, o repertório sai sob "Músicas"', () {
    final text = buildScheduleShareText(
      sampleEvent(
        songs: [
          {'songId': 's1', 'serviceId': 'x', 'title': 'Uma Canção', 'key': 'G'},
        ],
      ),
    );

    expect(text, contains('*Músicas*\n\n1. Uma Canção'));
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

    expect(text, contains('*Manhã*\n\n1. Abre Manhã\n2. Segue Manhã'));
    // A numeração recomeça: "a 2ª da noite" é como a equipe fala.
    expect(text, contains('*Noite*\n\n1. Abre Noite\n2. Abre Manhã'));
    // O rótulo do culto substitui o "Músicas": os dois juntos seriam três
    // cabeçalhos para duas listas.
    expect(text, isNot(contains('*Músicas*')));
  });

  test('culto sem música aparece dizendo que o repertório não saiu', () {
    final text = buildScheduleShareText(
      doisCultos(
        songs: [
          {'songId': 's1', 'serviceId': 's-manha', 'title': 'Só de Manhã'},
        ],
      ),
    );

    expect(text, contains('1. Só de Manhã'));
    // A noite entra nomeada, e não some: sem ela, quem canta à noite lê
    // "1. Só de Manhã" como o repertório do dia inteiro.
    expect(text, contains('*Noite*\n\nAinda não escolhidas.'));
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

  group('hinário e momento na linha da música', () {
    Map<String, Object?> hinario(int numero, String sigla) => {
          'hymnalId': 'h-$sigla',
          'name': sigla,
          'abbreviation': sigla,
          'number': numero,
          'isPrimary': true,
        };

    test('com os dois: "Nome - 314 CC (Dízimos e Ofertas)"', () {
      final text = buildScheduleShareText(
        sampleEvent(
          songs: [
            {
              'songId': 's1',
              'title': 'Estou Seguro',
              'hymnals': [hinario(314, 'CC')],
              'moment': 'DIZIMOS_E_OFERTAS',
            },
          ],
        ),
      );

      expect(text, contains('1. Estou Seguro - 314 CC (Dízimos e Ofertas)'));
    });

    test('só o hinário: "Nome - 208 HCC"', () {
      final text = buildScheduleShareText(
        sampleEvent(
          songs: [
            {
              'songId': 's1',
              'title': 'Eu Não Posso Fugir do Teu Espírito',
              'hymnals': [hinario(208, 'HCC')],
            },
          ],
        ),
      );

      expect(
        text,
        contains('1. Eu Não Posso Fugir do Teu Espírito - 208 HCC\n'),
      );
      expect(text, isNot(contains('(')));
    });

    test('só o momento: "Nome (Abertura)"', () {
      final text = buildScheduleShareText(
        sampleEvent(
          songs: [
            {'songId': 's1', 'title': 'Alfa e Ômega', 'moment': 'ABERTURA'},
          ],
        ),
      );

      expect(text, contains('1. Alfa e Ômega (Abertura)'));
      // Sem hinário nenhum: nada de traço solto esperando um número.
      expect(text, isNot(contains('Alfa e Ômega -')));
    });

    test('sem nenhum dos dois, sai só o nome', () {
      final text = buildScheduleShareText(
        sampleEvent(
          songs: [
            {'songId': 's1', 'title': 'Nosso General'},
          ],
        ),
      );

      // A maioria das linhas é assim. Um "( )" ou um "—" em cada uma faria a
      // mensagem parecer um formulário por preencher.
      expect(text, contains('1. Nosso General\n'));
      expect(text, isNot(contains('Nosso General -')));
      expect(text, isNot(contains('Nosso General (')));
    });

    test('"Outro" sai com o nome escrito à mão', () {
      final text = buildScheduleShareText(
        sampleEvent(
          songs: [
            {
              'songId': 's1',
              'title': 'Invoca-me',
              'moment': 'OUTRO',
              'momentLabel': 'Santa Ceia',
            },
          ],
        ),
      );

      expect(text, contains('1. Invoca-me (Santa Ceia)'));
      expect(text, isNot(contains('(Outro)')));
    });

    test('hinário, momento e "Nova" convivem na mesma linha', () {
      final text = buildScheduleShareText(
        sampleEvent(
          songs: [
            {
              'songId': 's1',
              'title': 'Os Que Confiam',
              'hymnals': [hinario(451, 'CC')],
              'moment': 'DIZIMOS_E_OFERTAS',
              'isNew': true,
            },
          ],
        ),
      );

      expect(
        text,
        contains('1. Os Que Confiam - 451 CC (Dízimos e Ofertas) — *Nova*'),
      );
    });

    test('nem artista nem tom entram, mesmo com hinário e momento', () {
      final text = buildScheduleShareText(
        sampleEvent(
          songs: [
            {
              'songId': 's1',
              'title': 'Estou Seguro',
              'artist': 'Cantor Cristão',
              'key': 'G',
              'hymnals': [hinario(314, 'CC')],
              'moment': 'ABERTURA',
            },
          ],
        ),
      );

      expect(text, isNot(contains('Cantor Cristão')));
      expect(text, isNot(contains('Tom')));
      expect(text, isNot(contains('(G)')));
    });

    test('a música em dois hinários mostra só a principal', () {
      final text = buildScheduleShareText(
        sampleEvent(
          songs: [
            {
              'songId': 's1',
              'title': 'Santo, Santo, Santo',
              'hymnals': [hinario(12, 'HCC'), hinario(5, 'CC')],
            },
          ],
        ),
      );

      // Duas siglas na mesma linha é ruído numa mensagem feita para ser lida
      // de relance. A principal vem na frente, do servidor.
      expect(text, contains('1. Santo, Santo, Santo - 12 HCC\n'));
      expect(text, isNot(contains('5 CC')));
    });
  });

  test('a mensagem não tem emoji nenhum', () {
    // Dois cultos, duas funções, observações e paleta: o caso que mais
    // multiplicava marcador nas versões anteriores. O negrito do WhatsApp faz
    // o trabalho que o emoji fazia, e renderiza igual em todo aparelho.
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

    expect(emojis, 0, reason: 'texto gerado:\n$text');
    expect(text, contains('*Vocal:* Samuel *(Ministrante)* e Maria'));
  });
}
