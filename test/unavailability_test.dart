import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/unavailability/domain/unavailability_models.dart';

Map<String, dynamic> eventJson({
  List<Map<String, dynamic>> unavailable = const [],
  List<Map<String, dynamic>> unavailableAssigned = const [],
}) {
  return {
    'id': 'e1',
    'teamId': 't1',
    'title': 'Domingo de manhã',
    'startsAt': '2026-08-16T12:00:00.000Z',
    'rehearsalAt': null,
    'location': null,
    'notes': null,
    'colorPalette': null,
    'status': 'PUBLISHED',
    'timezone': 'America/Sao_Paulo',
    'assignments': const [],
    'songs': const [],
    'unavailable': unavailable,
    'warnings': {'unavailableAssigned': unavailableAssigned},
  };
}

void main() {
  group('Unavailability', () {
    test('data vem como dia civil, sem hora nem fuso', () {
      final item = Unavailability.fromJson({
        'id': 'u1',
        'membershipId': 'm1',
        'date': '2026-08-16',
        'reason': 'Viagem',
      });

      expect(item.date.year, 2026);
      expect(item.date.month, 8);
      expect(item.date.day, 16);
      // Sem conversão de fuso: um `DateTime.utc` aqui poderia voltar para 15.
      expect(item.date.isUtc, isFalse);
      expect(item.reason, 'Viagem');
    });

    test('motivo é opcional', () {
      final item = Unavailability.fromJson({
        'id': 'u1',
        'membershipId': 'm1',
        'date': '2026-08-16',
        'reason': null,
      });

      expect(item.reason, isNull);
    });
  });

  group('Escala com indisponibilidade', () {
    test('lê quem avisou que não pode no dia', () {
      final event = Event.fromJson(
        eventJson(
          unavailable: [
            {
              'membershipId': 'm1',
              'displayName': 'Joao',
              'reason': 'Viagem',
            },
          ],
        ),
      );

      expect(event.unavailable, hasLength(1));
      expect(event.unavailable.first.displayName, 'Joao');
      expect(event.unavailable.first.reason, 'Viagem');
    });

    test('sem indisponibilidade a lista vem vazia, nunca nula', () {
      final event = Event.fromJson(eventJson());
      expect(event.unavailable, isEmpty);
      expect(event.warnings.unavailableAssigned, isEmpty);
    });

    test('avisa quando alguém escalado tinha marcado ausência', () {
      final event = Event.fromJson(
        eventJson(
          unavailableAssigned: [
            {'membershipId': 'm1', 'displayName': 'Joao', 'reason': null},
          ],
        ),
      );

      expect(event.warnings.unavailableAssigned, hasLength(1));
      expect(event.warnings.unavailableAssigned.first.displayName, 'Joao');
    });
  });
}
