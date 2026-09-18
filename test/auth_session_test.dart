import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:louvor_app/core/storage/token_storage.dart';
import 'package:louvor_app/features/auth/application/biometric_service.dart';

class MemoryStorage extends FlutterSecureStorage {
  MemoryStorage();

  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sessao persiste e logout remove tokens e configuracao biometrica',
      () async {
    final secure = MemoryStorage();
    final storage = TokenStorage(secure);
    await storage.save(accessToken: 'acesso', refreshToken: 'renovacao');
    await storage.enableBiometrics('usuario-a');
    final restored = TokenStorage(secure);
    expect(await restored.readRefreshToken(), 'renovacao');
    expect(await restored.readBiometricUserId(), 'usuario-a');
    await restored.clear();
    expect(await TokenStorage(secure).readRefreshToken(), isNull);
    expect(await restored.readBiometricUserId(), isNull);
  });

  test('refresh antigo nao pode ressuscitar sessao apos logout', () async {
    final storage = TokenStorage(MemoryStorage());
    await storage.save(accessToken: 'a', refreshToken: 'r1');
    await storage.clear();
    expect(
      await storage.saveRotatedIfCurrent(
        previousRefreshToken: 'r1',
        accessToken: 'b',
        refreshToken: 'r2',
      ),
      isFalse,
    );
    expect(await storage.readRefreshToken(), isNull);
  });

  test('plataforma sem biometria nao mostra nem executa autenticacao',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final biometrics = BiometricService(LocalAuthentication());
      expect(await biometrics.available, isFalse);
      expect(await biometrics.confirm(), isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
