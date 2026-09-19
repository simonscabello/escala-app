import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
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

/// De quanto em quanto tempo, no máximo, voltar ao app reconsulta /version.
const _recheckAfter = Duration(minutes: 15);

/// Mantém o resultado enquanto o app está na tela; não há razão para consultar
/// /version a cada troca entre Agenda, Equipe e Perfil.
///
/// **Mas volta a consultar quando o app sai do segundo plano.** O Android
/// mantém o processo vivo por dias, e com uma consulta só por sessão quem
/// nunca fecha o app não via a versão nova. O intervalo mínimo existe porque
/// voltar de um compartilhamento ou do seletor de arquivos também é "voltar".
/// O toque no push de versão nova não espera o intervalo: o
/// [PushCoordinator] invalida este provider direto.
final appUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) {
  final checkedAt = DateTime.now();
  final listener = AppLifecycleListener(
    onResume: () {
      if (DateTime.now().difference(checkedAt) >= _recheckAfter) {
        ref.invalidateSelf();
      }
    },
  );
  ref.onDispose(listener.dispose);
  return ref.watch(versionRepositoryProvider).check();
});
