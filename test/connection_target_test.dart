import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/health/domain/connection_target.dart';

/// O diagnóstico de conexão não expõe o endereço de produção, e continua
/// mostrando o do servidor local — que é o que quem desenvolve precisa ver.
void main() {
  const producao = 'https://backend-production-b304.up.railway.app';

  test('produção vira "Servidor da Pauta", sem o endereço', () {
    final server = describeServer(producao);

    expect(server.label, 'Servidor da Pauta');
    expect(server.detail, 'Conexão segura');
    expect(server.isLocal, isFalse);
    expect('${server.label} ${server.detail}', isNot(contains('railway')));
  });

  test('servidor local mostra host e porta', () {
    expect(describeServer('http://10.0.2.2:3000').detail, '10.0.2.2:3000');
    expect(describeServer('http://localhost:3000').label, 'Servidor local');
    expect(describeServer('http://192.168.0.10:3000').isLocal, isTrue);
  });

  test('o endereço de produção sai das mensagens de erro', () {
    final texto = redactServerAddress(
      'Falha em $producao/health (backend-production-b304.up.railway.app)',
      producao,
    );

    expect(texto, isNot(contains('railway')));
    expect(texto, contains('servidor da Pauta'));
    expect(
      redactServerAddress('Falha em http://10.0.2.2:3000', 'http://10.0.2.2:3000'),
      'Falha em http://10.0.2.2:3000',
    );
  });

  test('ambiente e tempo de resposta em português', () {
    expect(environmentLabel('production'), 'Produção');
    expect(responseTimeLabel(const Duration(milliseconds: 120)), 'Rápida (120 ms)');
    expect(responseTimeLabel(const Duration(milliseconds: 800)), 'Normal (800 ms)');
    expect(responseTimeLabel(const Duration(milliseconds: 2400)), 'Lenta (2,4 s)');
  });
}
