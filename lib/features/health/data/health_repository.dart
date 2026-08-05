import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/health_status.dart';

class HealthRepository {
  const HealthRepository(this._dio);

  final Dio _dio;

  Future<HealthStatus> check() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/health');
      return HealthStatus.fromJson(response.data!);
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
