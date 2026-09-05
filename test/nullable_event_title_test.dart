import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/team/domain/service_template.dart';

/// Título de escala chega nulo, e isso é o normal.
///
/// `Event.title` só existe em culto especial ("Páscoa"); o domingo comum é
/// identificado pela data. Duas listas carregam o título de **outra** escala
/// -- o aviso de mesmo dia e as escalas futuras da grade -- e as duas faziam
/// `as String` num campo que o backend sempre declarou `string | null`.
///
/// O estrago era desproporcional ao campo: como o cast estoura dentro do
/// `fromJson`, a escala inteira deixava de abrir, e a tela dizia "Não foi
/// possível carregar a escala" -- a mensagem de rede fora do ar, que aponta
/// para o servidor em vez de para o parse aqui dentro.
Map<String, dynamic> eventJson({required List<Map<String, dynamic>> conflitos}) {
  return {
    'id': 'e1',
    'teamId': 't1',
    'title': null,
    'startsAt': '2026-08-16T12:00:00.000Z',
    'status': 'PUBLISHED',
    'timezone': 'America/Sao_Paulo',
    'assignments': const [],
    'songs': const [],
    'services': const [],
    'unavailable': const [],
    'warnings': {'sameDayConflicts': conflitos},
  };
}

void main() {
  /// O que quebrava a tela: a escala inteira deixava de abrir por causa de um
  /// aviso secundário. E o erro aparecia como "Não foi possível carregar a
  /// escala", que é a mensagem de falha de rede -- parecia o servidor fora do
  /// ar, quando era o parse aqui dentro.
  test('outra escala sem título não impede a escala de carregar', () {
    final event = Event.fromJson(
      eventJson(
        conflitos: [
          {
            'membershipId': 'm1',
            'displayName': 'Maria',
            'otherEventId': 'e2',
            'otherEventTitle': null,
          },
        ],
      ),
    );

    final conflito = event.warnings.sameDayConflicts.single;
    expect(conflito.displayName, 'Maria');
    expect(conflito.otherEventTitle, isNull);
  });

  test('culto especial mantém o título da outra escala', () {
    final event = Event.fromJson(
      eventJson(
        conflitos: [
          {
            'membershipId': 'm1',
            'displayName': 'Maria',
            'otherEventId': 'e2',
            'otherEventTitle': 'Páscoa',
          },
        ],
      ),
    );

    expect(event.warnings.sameDayConflicts.single.otherEventTitle, 'Páscoa');
  });

  /// Campo ausente e campo nulo precisam cair no mesmo lugar: cache gravado
  /// por uma versão anterior do app não traz a chave.
  test('sem a chave, o título fica nulo em vez de estourar', () {
    final event = Event.fromJson(
      eventJson(
        conflitos: [
          {
            'membershipId': 'm1',
            'displayName': 'Maria',
            'otherEventId': 'e2',
          },
        ],
      ),
    );

    expect(event.warnings.sameDayConflicts.single.otherEventTitle, isNull);
  });

  /// O mesmo cast não-nulável estava numa segunda lista: as escalas futuras
  /// que usam uma linha da grade. Ela é buscada ao salvar um horário da grade,
  /// e estourava fora do `on ApiException` -- a gravação morria sem mensagem.
  test('escala futura sem título não quebra a lista da grade', () {
    final afetada = AffectedEvent.fromJson({
      'eventId': 'e2',
      'title': null,
      'startsAt': '2026-08-16T12:00:00.000Z',
      'label': 'Manhã',
    });

    expect(afetada.eventId, 'e2');
    expect(afetada.title, isNull);
    expect(afetada.label, 'Manhã');
  });
}
