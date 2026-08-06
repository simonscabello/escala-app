import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';

Map<String, dynamic> member(String id, String name) => {
      'id': 'a-$id',
      'membershipId': id,
      'displayName': name,
      'note': null,
      'isRegisteredForPosition': false,
    };

Map<String, dynamic> group(
  String positionId,
  String name,
  List<Map<String, dynamic>> members,
) =>
    {
      'positionId': positionId,
      'positionName': name,
      'sortOrder': 0,
      'members': members,
    };

Map<String, dynamic> eventJson(List<Map<String, dynamic>> assignments) => {
      'id': 'e1',
      'teamId': 't1',
      'title': 'Culto de Domingo',
      'startsAt': '2026-08-09T12:00:00.000Z',
      'rehearsalAt': '2026-08-08T22:00:00.000Z',
      'location': null,
      'notes': null,
      'colorPalette': 'Preto e dourado',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': assignments,
      'songs': const [],
    };

void main() {
  test('conta pessoas distintas em várias funções', () {
    // Reproduz a escala real: 7 pessoas, com Samuel em duas funções.
    final event = Event.fromJson(
      eventJson([
        group('p1', 'Vocalista', [
          member('m-maria', 'Maria'),
          member('m-pedro', 'Pedro Alves'),
          member('m-samuel', 'Samuel'),
        ]),
        group('p2', 'Violão', [member('m-samuel', 'Samuel')]),
        group('p3', 'Guitarra', [member('m-joao', 'Joao')]),
        group('p4', 'Baixo', [member('m-rafael', 'Rafael')]),
        group('p5', 'Bateria', [member('m-task3', 'Membro Task 3')]),
        group('p6', 'Multimídia', [member('m-vanessa', 'Vanessa')]),
      ]),
    );

    expect(event.assignments, hasLength(6));
    // Samuel aparece duas vezes e conta uma só.
    expect(event.scheduledMemberCount, 7);
  });

  test('escala vazia conta zero', () {
    expect(Event.fromJson(eventJson([])).scheduledMemberCount, 0);
  });

  test('mesma pessoa em duas funções conta uma vez', () {
    final event = Event.fromJson(
      eventJson([
        group('p1', 'Vocalista', [member('m-samuel', 'Samuel')]),
        group('p2', 'Violão', [member('m-samuel', 'Samuel')]),
      ]),
    );

    expect(event.scheduledMemberCount, 1);
  });
}
