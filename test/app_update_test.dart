import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/update/domain/app_update_info.dart';

void main() {
  test('detecta versão funcional mais nova', () {
    expect(isVersionNewer('0.2.0', '0.1.9+12'), isTrue);
    expect(isVersionNewer('1.0.0', '0.9.99'), isTrue);
  });

  test('usa o número do build quando a versão é igual', () {
    expect(isVersionNewer('0.1.0+2', '0.1.0+1'), isTrue);
    expect(isVersionNewer('0.1.0+1', '0.1.0+2'), isFalse);
  });

  test('não avisa para a mesma versão ou uma anterior', () {
    expect(isVersionNewer('0.1.0', '0.1.0'), isFalse);
    expect(isVersionNewer('0.1.0', '0.1.1'), isFalse);
  });
}
