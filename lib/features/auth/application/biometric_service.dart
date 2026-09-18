import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// O plugin nativo nunca e chamado na Web.
class BiometricService {
  BiometricService(this._auth);

  final LocalAuthentication _auth;

  Future<bool> get available async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirm() async {
    if (!await available) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirme sua identidade para entrar no Pauta',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Cancelamento, bloqueio, remoção de digitais e indisponibilidade
      // seguem todos para o login por senha.
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(LocalAuthentication()),
);

/// Se o aparelho oferece biometria. A tela decide por aqui se a linha existe:
/// um [AppGroup] desenha divisor antes de cada filho, inclusive de um vazio.
final biometricsAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(biometricServiceProvider).available,
);
