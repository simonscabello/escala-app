import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Anexa o access token e, diante de um 401, tenta renovar a sessao uma vez e
/// repetir a requisicao. Se a renovacao falhar, limpa os tokens e avisa o app.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required Future<void> Function() onSessionExpired,
  })  : _storage = storage,
        _onSessionExpired = onSessionExpired;

  final TokenStorage _storage;
  final Future<void> Function() _onSessionExpired;

  /// Dio proprio, sem interceptors: renovar a sessao não pode cair no mesmo
  /// tratamento de 401 e virar recursao.
  final Dio _refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiUrl));

  /// Varias requisicoes podem receber 401 ao mesmo tempo; todas esperam a mesma
  /// renovacao em vez de dispararem uma cada.
  Future<bool>? _refreshing;

  /// Rotas que nunca devem tentar renovar: não ha sessao a renovar nelas.
  static const _skipPaths = {
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/logout',
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_skipPaths.contains(options.path)) {
      final token = await _storage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = options.extra['retried'] == true;

    if (!isUnauthorized ||
        alreadyRetried ||
        _skipPaths.contains(options.path)) {
      return handler.next(err);
    }

    // Outra requisicao pode ter renovado a sessao entre o envio e este 401.
    // Reusar o refresh antigo aqui seria interpretado como replay no servidor.
    final currentAccess = await _storage.readAccessToken();
    final failedAccess = options.headers['Authorization'];
    if (currentAccess != null && failedAccess != 'Bearer $currentAccess') {
      return _retry(options, handler);
    }

    final pending = _refreshing ??= _refresh();
    final renewed = await pending;
    if (identical(_refreshing, pending)) _refreshing = null;

    if (!renewed) {
      return handler.next(err);
    }

    return _retry(options, handler);
  }

  Future<void> _retry(
    RequestOptions options,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      options.extra['retried'] = true;
      options.headers['Authorization'] =
          'Bearer ${await _storage.readAccessToken()}';
      final response = await _refreshDio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) {
      await _onSessionExpired();
      return false;
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final saved = await _storage.saveRotatedIfCurrent(
        previousRefreshToken: refreshToken,
        accessToken: response.data!['accessToken'] as String,
        refreshToken: response.data!['refreshToken'] as String,
      );
      return saved;
    } on DioException catch (e) {
      // So o servidor recusando a credencial encerra a sessao. Sem rede ou com
      // timeout o refresh token continua valido, e apaga-lo deslogaria quem so
      // abriu o app no metro.
      final status = e.response?.statusCode;
      if (status != 401 && status != 400) return false;
      if (await _storage.clearIfRefreshMatches(refreshToken)) {
        await _onSessionExpired();
      }
      return false;
    }
  }
}
