import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/unavailability_models.dart';

class UnavailabilityRepository {
  const UnavailabilityRepository(this._dio);

  final Dio _dio;

  Future<List<Unavailability>> listMine(String teamId) {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/unavailabilities/me',
      );
      return response.data!
          .map((e) => Unavailability.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<Unavailability>> add(
    String teamId, {
    required List<DateTime> dates,
    String? reason,
    String? membershipId,
  }) {
    return _guard(() async {
      final response = await _dio.post<List<dynamic>>(
        '/teams/$teamId/unavailabilities',
        data: {
          'dates': dates.map(_toDateKey).toList(),
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (membershipId != null) 'membershipId': membershipId,
        },
      );
      return response.data!
          .map((e) => Unavailability.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> remove(String teamId, String id) {
    return _guard(() async {
      await _dio.delete<void>('/teams/$teamId/unavailabilities/$id');
    });
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

String _toDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

final unavailabilityRepositoryProvider =
    Provider<UnavailabilityRepository>((ref) {
  return UnavailabilityRepository(ref.watch(dioProvider));
});

final myUnavailabilityProvider =
    FutureProvider.autoDispose.family<List<Unavailability>, String>(
  (ref, teamId) =>
      ref.watch(unavailabilityRepositoryProvider).listMine(teamId),
);
