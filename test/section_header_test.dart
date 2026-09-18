import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/shared/widgets/section_header.dart';

void main() {
  testWidgets('a ação fica na mesma altura do título', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            title: 'Equipe escalada',
            trailing: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
          ),
        ),
      ),
    );

    final title = tester.getCenter(find.text('Equipe escalada')).dy;
    final action = tester.getCenter(find.text('Editar')).dy;
    expect((title - action).abs(), lessThan(1));
  });
}
