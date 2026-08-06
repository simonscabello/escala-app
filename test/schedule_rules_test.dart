import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/events/domain/schedule_share_text.dart';
import 'package:louvor_app/features/team/domain/team_models.dart';
import 'package:timezone/data/latest.dart' as tzdata;

Position position(String name, String category) => Position.fromJson({
      'id': name.toLowerCase(),
      'name': name,
      'category': category,
    });

Map<String, dynamic> eventJson({String? rehearsalAt}) => {
      'id': 'e1',
      'teamId': 't1',
      'title': 'Culto de Domingo',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'rehearsalAt': rehearsalAt,
      'location': null,
      'notes': null,
      'colorPalette': 'Preto e dourado',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': const [],
      'songs': const [],
    };

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });

  group('Categorias de função', () {
    test('vocal, instrumento e apoio técnico são distinguidos', () {
      expect(position('Vocalista', 'VOCAL').isVocal, isTrue);
      expect(position('Vocalista', 'VOCAL').isInstrument, isFalse);

      expect(position('Baixo', 'INSTRUMENT').isInstrument, isTrue);
      expect(position('Baixo', 'INSTRUMENT').isTech, isFalse);

      expect(position('Multimídia', 'TECH').isTech, isTrue);
      expect(position('Som', 'TECH').isTech, isTrue);
      // Multimídia e som não são instrumentos: é isso que os mantém fora da
      // regra de "um instrumento por pessoa" e dentro da de "fora da banda".
      expect(position('Som', 'TECH').isInstrument, isFalse);
    });
  });

  group('Convidado', () {
    Map<String, dynamic> memberJson({bool isGuest = false}) => {
          'id': 'm1',
          'displayName': 'Ana',
          'role': 'MEMBER',
          'hasAccount': false,
          'isGuest': isGuest,
          'phone': null,
          'email': null,
          'positions': const [],
        };

    test('convidado é identificado', () {
      expect(Member.fromJson(memberJson(isGuest: true)).isGuest, isTrue);
    });

    test('integrante normal não é convidado', () {
      expect(Member.fromJson(memberJson()).isGuest, isFalse);
    });

    test('ausência do campo não quebra respostas antigas', () {
      final json = memberJson()..remove('isGuest');
      expect(Member.fromJson(json).isGuest, isFalse);
    });
  });

  group('Texto compartilhado', () {
    test('diz "Sem ensaio" quando não há ensaio marcado', () {
      final texto = buildScheduleShareText(Event.fromJson(eventJson()));
      expect(texto, contains('Sem ensaio'));
    });

    test('mostra o horário quando há ensaio', () {
      final texto = buildScheduleShareText(
        Event.fromJson(eventJson(rehearsalAt: '2026-08-15T22:00:00.000Z')),
      );
      expect(texto.contains('Sem ensaio'), isFalse);
      expect(texto, contains('19:00'));
    });

    test('leva paleta e data, que é o que o convidado precisa saber', () {
      final texto = buildScheduleShareText(Event.fromJson(eventJson()));
      expect(texto, contains('Preto e dourado'));
      expect(texto, contains('Culto de Domingo'));
      expect(texto.toLowerCase(), contains('agosto'));
    });
  });
}
