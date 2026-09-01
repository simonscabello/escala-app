import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/core/storage/shared_preferences_provider.dart';
import 'package:louvor_app/features/auth/application/auth_controller.dart';
import 'package:louvor_app/features/auth/domain/auth_models.dart';
import 'package:louvor_app/features/profile/presentation/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mostra nome, e-mail e botao sair', (tester) async {
    // O seletor de tema do perfil le a preferencia do aparelho.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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
    expect(find.text('Meus dados'), findsOneWidget);
    expect(find.text('Alterar senha'), findsOneWidget);

    // O seletor de tema empurrou "Sair" para fora da viewport padrao do
    // teste; ListView so monta o que esta visivel.
    await tester.scrollUntilVisible(
      find.text('Sair da conta'),
      200,
      scrollable: find.byType(Scrollable),
    );
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
