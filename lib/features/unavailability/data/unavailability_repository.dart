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

  /// A equipe inteira num intervalo de dias. É o que alimenta o calendário do
  /// líder: ele precisa ver o mês antes de montar as escalas, e não descobrir
  /// a ausência ao abrir a escala de um domingo específico.
  Future<List<Unavailability>> listTeam(
    String teamId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/unavailabilities',
        queryParameters: {'from': _toDateKey(from), 'to': _toDateKey(to)},
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

/// Um mês civil de uma equipe. A chave é o mês, e não um intervalo livre:
/// o calendário anda de mês em mês, e assim voltar ao mês anterior reaproveita
/// o que já foi carregado.
typedef TeamMonth = ({String teamId, int year, int month});

final teamUnavailabilityProvider =
    FutureProvider.autoDispose.family<List<Unavailability>, TeamMonth>(
  (ref, month) => ref.watch(unavailabilityRepositoryProvider).listTeam(
        month.teamId,
        from: DateTime(month.year, month.month, 1),
        // Dia zero do mês seguinte é o último dia deste — sem tabela de 28,
        // 30, 31 e fevereiro bissexto.
        to: DateTime(month.year, month.month + 1, 0),
      ),
);
