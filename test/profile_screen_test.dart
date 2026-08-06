import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/auth/application/auth_controller.dart';
import 'package:louvor_app/features/auth/domain/auth_models.dart';
import 'package:louvor_app/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('mostra nome, e-mail e botao sair', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => FakeAuthController(
              ref,
              AuthState.signedIn(
                const AuthUser(
                  id: '1',
                  name: 'Samuel',
                  email: 'samuel@teste.com',
                  mustChangePassword: false,
                ),
                const [
                  TeamSummary(
                    membershipId: 'm1',
                    teamId: 't1',
                    name: 'Ministerio de Louvor',
                    role: 'OWNER',
                    displayName: 'Samuel',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfileScreen(),
        ),
      ),
    );

    expect(find.text('Samuel'), findsWidgets);
    expect(find.text('samuel@teste.com'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);
  });
}

class FakeAuthController extends AuthController {
  FakeAuthController(super.ref, this._initial);

  final AuthState _initial;

  @override
  Future<void> bootstrap() async {
    state = _initial;
  }
}
