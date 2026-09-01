import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/assignments/presentation/assignment_form_screen.dart';

void main() {
  test('preserva o recado individual ao remontar a escalação', () {
    final payload = buildAssignmentPayload(
      {
        'guitarra': {'maria'},
        'vocal': {'maria', 'joao'},
      },
      {
        ('guitarra', 'maria'): 'Levar o violão reserva',
        ('vocal', 'joao'): 'Segunda voz',
      },
    );

    expect(
      payload,
      contains(
        allOf(
          containsPair('membershipId', 'maria'),
          containsPair('positionId', 'guitarra'),
          containsPair('note', 'Levar o violão reserva'),
        ),
      ),
    );
    expect(
      payload,
      contains(
        allOf(
          containsPair('membershipId', 'joao'),
          containsPair('positionId', 'vocal'),
          containsPair('note', 'Segunda voz'),
        ),
      ),
    );
    expect(
      payload,
      contains(
        allOf(
          containsPair('membershipId', 'maria'),
          containsPair('positionId', 'vocal'),
          isNot(containsPair('note', anything)),
        ),
      ),
    );
  });

  test('não envia recado de quem saiu da escalação', () {
    final payload = buildAssignmentPayload(
      {
        'guitarra': {'joao'},
      },
      {
        ('guitarra', 'maria'): 'Recado antigo',
      },
    );

    expect(payload, [
      {'membershipId': 'joao', 'positionId': 'guitarra'},
    ]);
  });
}
