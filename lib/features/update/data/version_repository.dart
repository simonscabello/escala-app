import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/dio_client.dart';
import '../domain/app_update_info.dart';

class VersionRepository {
  const VersionRepository(this._dio);

  final Dio _dio;

  Future<AppUpdateInfo?> check() async {
    try {
      final results = await Future.wait([
        _dio.get<Map<String, dynamic>>('/version'),
        PackageInfo.fromPlatform(),
      ]);
      final response = results[0] as Response<Map<String, dynamic>>;
      final package = results[1] as PackageInfo;
      final data = response.data!;
      final latest = data['latestAppVersion'] as String?;
      if (latest == null || latest.isEmpty) return null;

      final installed = package.buildNumber.isEmpty
          ? package.version
          : '${package.version}+${package.buildNumber}';
      return AppUpdateInfo(
        installedVersion: installed,
        latestVersion: latest,
        apkUrl: data['apkUrl'] as String?,
      );
    } on DioException {
      // Atualização é um aviso auxiliar: falhar aqui nunca pode esconder a
      // agenda nem transformar a abertura do app em erro.
      return null;
    } on FormatException {
      // Uma versão mal configurada no servidor também não bloqueia o app.
      return null;
    }
  }
}

final versionRepositoryProvider = Provider<VersionRepository>((ref) {
  return VersionRepository(ref.watch(rootDioProvider));
});

/// Mantém o resultado durante a sessão; não há razão para consultar /version
/// a cada troca entre Agenda, Equipe e Perfil.
final appUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) {
  return ref.watch(versionRepositoryProvider).check();
});
