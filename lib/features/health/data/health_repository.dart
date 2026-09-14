import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/health_status.dart';

class HealthRepository {
  const HealthRepository(this._dio);

  final Dio _dio;

  Future<HealthStatus> check() async {
    final relogio = Stopwatch()..start();
    try {
      final response = await _dio.get<Map<String, dynamic>>('/health');
      relogio.stop();
      return HealthStatus.fromJson(
        response.data!,
        responseTime: relogio.elapsed,
        checkedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.watch(rootDioProvider));
});

final healthCheckProvider = FutureProvider.autoDispose<HealthStatus>((ref) {
  return ref.watch(healthRepositoryProvider).check();
});

/// A versão instalada do app, "0.15.0 (18)". Nula quando a plataforma não
/// informa — a linha simplesmente não aparece.
final installedAppVersionProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
  } catch (_) {
    return null;
  }
});
