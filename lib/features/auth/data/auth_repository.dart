import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/auth_models.dart';

class MeResult {
  const MeResult({required this.user, required this.teams});

  final AuthUser user;
  final List<TeamSummary> teams;
}

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<Session> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<Session> login({
    required String email,
    required String password,
  }) {
    return _post('/auth/login', {'email': email, 'password': password});
  }

  Future<Session> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _post('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// Envia so o que mudou: mandar o e-mail atual de volta gastaria uma
  /// checagem de unicidade a toa.
  Future<AuthUser> updateProfile({String? name, String? email}) async {
    return _patchUser({
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
  }

  /// Envia a foto como **bytes**, e não como caminho de arquivo.
  ///
  /// `MultipartFile.fromFile` usa `dart:io`, que não existe no navegador: no
  /// Flutter Web o `path` de um `XFile` é uma URL `blob:` e a chamada falha em
  /// tempo de execução. Ler os bytes funciona nas duas plataformas com o mesmo
  /// código, sem `kIsWeb` em lugar nenhum.
  ///
  /// O `filename` vai junto só para o servidor ter um nome no multipart — o
  /// backend não confia nele: ele decide o tipo pela assinatura do conteúdo
  /// (ver `StorageService.saveImage`) e grava com um UUID próprio.
  Future<AuthUser> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/users/me/avatar',
        data: form,
        // Enviar imagem e mais lento do que uma chamada JSON: o timeout padrao
        // (10s) derrubava o envio em rede de celular ruim.
        options: Options(sendTimeout: const Duration(seconds: 60)),
      );
      return AuthUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AuthUser> removeAvatar() async {
    try {
      final response =
          await _dio.delete<Map<String, dynamic>>('/users/me/avatar');
      return AuthUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<MeResult> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = response.data!;
      return MeResult(
        user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
        teams: (data['teams'] as List<dynamic>)
            .map((e) => TeamSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException {
      // Sair localmente e o que importa: se o servidor não respondeu, o token
      // expira sozinho.
    }
  }

  Future<AuthUser> _patchUser(Map<String, dynamic> body) async {
    try {
      final response =
          await _dio.patch<Map<String, dynamic>>('/users/me', data: body);
      return AuthUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Session> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return Session.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
