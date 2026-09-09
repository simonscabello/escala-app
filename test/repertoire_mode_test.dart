import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/events/domain/schedule_share_text.dart';
import 'package:louvor_app/features/events/presentation/event_schedule_facts.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Repertório planejado x definido na hora.
///
/// O culto de quinta da igreja não tem lista: quem ministra escolhe ali. Antes
/// deste campo, toda escala assim aparecia como pela metade — "músicas a
/// definir" na agenda, na manchete da Home e no texto que vai para o grupo do
/// WhatsApp.
///
/// O que estes testes protegem é a **fronteira**: escala planejada continua
/// cobrando exatamente como cobrava, e escala na hora não cobra em lugar
/// nenhum.
Map<String, dynamic> _eventJson({
  String? repertoireMode,
  List<Object?> songs = const [],
  int morningSongs = 0,
  int eveningSongs = 0,
}) {
  return {
    'id': 'e1',
    'teamId': 't1',
    'startsAt': '2026-09-06T12:00:00.000Z',
    'rehearsalAt': null,
    'location': null,
    'notes': null,
    'colorPalette': null,
    'status': 'PUBLISHED',
    'timezone': 'America/Sao_Paulo',
    if (repertoireMode != null) 'repertoireMode': repertoireMode,
    'assignments': const [],
    'songs': songs,
    'services': [
      {
        'id': 'manha',
        'label': 'Manhã',
        'startsAt': '2026-09-06T12:00:00.000Z',
        'songCount': morningSongs,
      },
      {
        'id': 'noite',
        'label': 'Noite',
        'startsAt': '2026-09-06T22:00:00.000Z',
        'songCount': eveningSongs,
      },
    ],
  };
}

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });

  group('leitura do campo', () {
    /// A compatibilidade que sustenta as duas pontas: o cache gravado antes
    /// deste campo existir e o backend que ainda não o devolve.
    test('campo ausente vale planejado', () {
      final event = Event.fromJson(_eventJson());

      expect(event.repertoireMode, RepertoireMode.planned);
      expect(event.isRepertoireOnTheFly, isFalse);
    });

    test('valor desconhecido não derruba a escala; vale planejado', () {
      final event = Event.fromJson(_eventJson(repertoireMode: 'IMPROVISADO'));

      expect(event.repertoireMode, RepertoireMode.planned);
    });

    test('o valor do servidor é lido', () {
      final event = Event.fromJson(_eventJson(repertoireMode: 'ON_THE_FLY'));

      expect(event.repertoireMode, RepertoireMode.onTheFly);
      expect(event.isRepertoireOnTheFly, isTrue);
    });
  });

  group('repertório vazio deixa de ser pendência', () {
    test('nenhum culto entra na lista de pendentes', () {
      final event = Event.fromJson(_eventJson(repertoireMode: 'ON_THE_FLY'));

      expect(event.servicesWithoutSongs, isEmpty);
      // Quem pergunta isto está sempre prestes a dizer que falta algo.
      expect(event.hasNoSongs, isFalse);
    });

    test('a escala planejada continua cobrando culto por culto', () {
      final event = Event.fromJson(_eventJson(morningSongs: 2));

      expect(event.servicesWithoutSongs, ['Noite']);
    });

    test('a linha da agenda diz o combinado em vez de cobrar', () {
      final naHora = ScheduleFacts.of(
        Event.fromJson(_eventJson(repertoireMode: 'ON_THE_FLY')),
        'America/Sao_Paulo',
      );
      final planejada = ScheduleFacts.of(
        Event.fromJson(_eventJson()),
        'America/Sao_Paulo',
      );

      expect(naHora.songs, 'Repertório definido na hora');
      expect(planejada.songs, 'Músicas a definir');
    });
  });

  group('texto compartilhado', () {
    /// Quem recebe a mensagem não tem o app para conferir: "ainda não
    /// escolhidas" o deixaria esperando uma segunda mensagem que nunca vem.
    test('sem música, diz que o repertório sai no culto', () {
      final text = buildScheduleShareText(
        Event.fromJson(_eventJson(repertoireMode: 'ON_THE_FLY')),
      );

      expect(text, contains('🎶 Músicas'));
      expect(text, contains('Definidas na hora, no culto.'));
      expect(text, isNot(contains('Ainda não escolhidas.')));
    });

    test('a escala planejada continua dizendo que faltam', () {
      final text = buildScheduleShareText(Event.fromJson(_eventJson()));

      expect(text, contains('Ainda não escolhidas.'));
    });

    /// Acontece: o ministrante deixa uma encaminhada e resolve o resto no
    /// culto. A lista aparece, mas ninguém a recebe como definitiva.
    test('com música já escolhida, a lista vem avisada', () {
      final text = buildScheduleShareText(
        Event.fromJson(
          _eventJson(
            repertoireMode: 'ON_THE_FLY',
            songs: [
              {
                'songId': 's1',
                'serviceId': 'manha',
                'title': 'Aclame ao Senhor',
              },
            ],
          ),
        ),
      );

      expect(text, contains('Definidas na hora. Por enquanto:'));
      expect(text, contains('1. Aclame ao Senhor'));
      // O culto sem música não é cobrado nem aqui.
      expect(text, contains('Definidas na hora, no culto.'));
      expect(text, isNot(contains('Ainda não escolhidas.')));
    });
  });
}
