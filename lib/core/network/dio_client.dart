import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Sinaliza que a sessao caiu e não pode ser renovada. O AuthController escuta
/// isto para devolver o usuario a tela de login.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

/// Cliente das rotas de negocio (/api/v1), com autenticacao automatica.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      onSessionExpired: () async {
        ref.read(sessionExpiredProvider.notifier).state++;
      },
    ),
  );

  return dio;
});

/// Cliente da raiz do servidor, usado apenas por /health.
final rootDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
    ),
  );
});
