import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/shared/widgets/greeting_header.dart';

void main() {
  test('a saudação acompanha a hora, inclusive de madrugada', () {
    expect(greetingForHour(0), 'Boa madrugada');
    expect(greetingForHour(4), 'Boa madrugada');
    expect(greetingForHour(5), 'Bom dia');
    expect(greetingForHour(11), 'Bom dia');
    expect(greetingForHour(12), 'Boa tarde');
    expect(greetingForHour(17), 'Boa tarde');
    expect(greetingForHour(18), 'Boa noite');
    expect(greetingForHour(23), 'Boa noite');
  });
}
