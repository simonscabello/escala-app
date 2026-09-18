import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda os tokens no armazenamento seguro do sistema (Keystore no Android).
///
/// Os valores ficam em cache na memoria depois da primeira leitura: no Android
/// o plugin faz o trabalho de criptografia na thread principal, e o interceptor
/// HTTP precisa do access token a cada requisicao. Sem o cache, cada chamada de
/// API pagaria uma operacao de Keystore na main thread -- caminho curto para
/// travar a interface em aparelho lento.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _biometricUserKey = 'biometric_user_id';
  static const _biometricOfferKey = 'biometric_offer_user_id';

  String? _accessToken;
  String? _refreshToken;
  Future<void>? _loading;
  bool _loaded = false;
  Future<void> _writes = Future.value();

  Future<void> _ensureLoaded() {
    if (_loaded) return Future.value();
    // Chamadas simultaneas esperam a mesma leitura.
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      _accessToken = await _storage.read(key: _accessKey);
      _refreshToken = await _storage.read(key: _refreshKey);
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  Future<String?> readAccessToken() async {
    await _ensureLoaded();
    return _accessToken;
  }

  Future<String?> readRefreshToken() async {
    await _ensureLoaded();
    return _refreshToken;
  }

  Future<String?> readBiometricUserId() =>
      _storage.read(key: _biometricUserKey);

  Future<void> enableBiometrics(String userId) =>
      _storage.write(key: _biometricUserKey, value: userId);

  Future<void> disableBiometrics() => _storage.delete(key: _biometricUserKey);

  Future<String?> readBiometricOfferUserId() =>
      _storage.read(key: _biometricOfferKey);

  Future<void> markBiometricOffer(String userId) =>
      _storage.write(key: _biometricOfferKey, value: userId);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _loaded = true;
    _writes = _writes.then((_) async {
      await _storage.write(key: _accessKey, value: accessToken);
      await _storage.write(key: _refreshKey, value: refreshToken);
    });
    await _writes;
  }

  Future<bool> saveRotatedIfCurrent({
    required String previousRefreshToken,
    required String accessToken,
    required String refreshToken,
  }) async {
    await _ensureLoaded();
    if (_refreshToken != previousRefreshToken) return false;
    await save(accessToken: accessToken, refreshToken: refreshToken);
    return true;
  }

  Future<bool> clearIfRefreshMatches(String expected) async {
    await _ensureLoaded();
    if (_refreshToken != expected) return false;
    await clear();
    return true;
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;
    _writes = _writes.then((_) async {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    });
    await _writes;
    await disableBiometrics();
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(
    // `encryptedSharedPreferences: true` traz o Jetpack Security/Tink junto e
    // pesa na inicializacao. O backend padrao (chave RSA no AndroidKeyStore +
    // AES nos valores) protege o refresh token adequadamente para este MVP.
    const FlutterSecureStorage(),
  );
});
