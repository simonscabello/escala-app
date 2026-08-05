import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/auth/application/auth_controller.dart';
import 'package:louvor_app/features/auth/domain/auth_models.dart';
import 'package:louvor_app/features/auth/presentation/login_screen.dart';

const _user = AuthUser(
  id: 'u1',
  name: 'Samuel Cabello',
  email: 'samuel@teste.com',
  mustChangePassword: false,
);

void main() {
  group('AuthState', () {
    test('usuario normal fica autenticado', () {
      expect(AuthState.signedIn(_user).status, AuthStatus.authenticated);
    });

    test('senha redefinida pelo líder trava em mustChangePassword', () {
      const resetUser = AuthUser(
        id: 'u1',
        name: 'Samuel',
        email: 'samuel@teste.com',
        mustChangePassword: true,
      );
      expect(
        AuthState.signedIn(resetUser).status,
        AuthStatus.mustChangePassword,
      );
    });
  });

  group('AuthUser', () {
    test('firstName usa apenas o primeiro nome', () {
      expect(_user.firstName, 'Samuel');
    });

    test('fromJson assume mustChangePassword falso quando ausente', () {
      final user = AuthUser.fromJson({
        'id': 'u1',
        'name': 'Samuel',
        'email': 'samuel@teste.com',
      });
      expect(user.mustChangePassword, isFalse);
    });
  });

  group('TeamSummary', () {
    test('OWNER e LEADER podem gerenciar; MEMBER nao', () {
      TeamSummary withRole(String role) => TeamSummary(
            membershipId: 'm1',
            teamId: 't1',
            name: 'Equipe',
            role: role,
            displayName: 'Samuel',
          );

      expect(withRole('OWNER').canManage, isTrue);
      expect(withRole('LEADER').canManage, isTrue);
      expect(withRole('MEMBER').canManage, isFalse);
    });
  });

  testWidgets('login valida os campos antes de chamar a API', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Informe um e-mail valido.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
  });
}
