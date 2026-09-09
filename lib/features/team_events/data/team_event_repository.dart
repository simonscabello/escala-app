import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/read_cache.dart';
import '../../events/data/event_repository.dart';
import '../domain/team_event.dart';

/// Os eventos da equipe, na mesma forma que as escalas.
///
/// **Mesmo cache de leitura, outra chave** (`team-events.<escopo>`): a agenda
/// aberta sem rede precisa mostrar o churrasco tanto quanto o domingo, e
/// duplicar o mecanismo por causa de uma tabela diferente seria manter dois
/// caminhos de offline que divergiriam no primeiro ajuste.
class TeamEventRepository {
  const TeamEventRepository(this._dio, this._cache);

  final Dio _dio;
  final ReadCache _cache;

  Future<CachedValue<List<TeamEvent>>> list(
    String teamId, {
    String scope = 'upcoming',
    int limit = 50,
  }) async {
    final cacheScope = 'team-events.$scope';
    try {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/team-events',
        queryParameters: {'scope': scope, 'limit': limit},
      );
      final maps = response.data!
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _cache.saveAgenda(teamId, cacheScope, maps);
      return CachedValue(
        data: maps.map(TeamEvent.fromJson).toList(),
        fromCache: false,
      );
    } on DioException catch (e) {
      final cached = _cache.readAgenda(teamId, cacheScope);
      if (cached != null) {
        return CachedValue(
          data: cached.data.map(TeamEvent.fromJson).toList(),
          fromCache: true,
          cachedAt: cached.cachedAt,
        );
      }
      throw ApiException.fromDio(e);
    }
  }

  Future<TeamEvent> find(String id) => _guard(() async {
        final response =
            await _dio.get<Map<String, dynamic>>('/team-events/$id');
        return TeamEvent.fromJson(response.data!);
      });

  Future<TeamEvent> create(
    String teamId, {
    required String title,
    required String startsAt,
    String? endsAt,
    String? location,
    String? notes,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/team-events',
        data: {
          'title': title,
          'startsAt': startsAt,
          if (endsAt != null) 'endsAt': endsAt,
          if (location != null && location.isNotEmpty) 'location': location,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return TeamEvent.fromJson(response.data!);
    });
  }

  /// Editar manda **tudo o que a tela mostra**, e não só o que mudou.
  ///
  /// `removeEndsAt` existe porque omitir preserva no servidor: sem ele, apagar
  /// a hora de término no formulário não teria como ser dito.
  Future<TeamEvent> update(
    String id, {
    String? title,
    String? startsAt,
    String? endsAt,
    bool removeEndsAt = false,
    String? location,
    String? notes,
  }) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/team-events/$id',
        data: {
          if (title != null) 'title': title,
          if (startsAt != null) 'startsAt': startsAt,
          if (removeEndsAt) 'endsAt': null,
          if (endsAt != null) 'endsAt': endsAt,
          if (location != null) 'location': location,
          if (notes != null) 'notes': notes,
        },
      );
      return TeamEvent.fromJson(response.data!);
    });
  }

  Future<void> remove(String id) =>
      _guard(() async => _dio.delete<void>('/team-events/$id'));

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final teamEventRepositoryProvider = Provider<TeamEventRepository>((ref) {
  return TeamEventRepository(
    ref.watch(dioProvider),
    ref.watch(readCacheProvider),
  );
});

/// A mesma chave de família das escalas (`(teamId, scope)`), para a agenda
/// poder pedir os dois lados com a mesma conta.
final teamEventsProvider = FutureProvider.autoDispose
    .family<CachedValue<List<TeamEvent>>, EventsQuery>((ref, query) {
  final (teamId, scope) = query;
  return ref.watch(teamEventRepositoryProvider).list(teamId, scope: scope);
});

final teamEventProvider =
    FutureProvider.autoDispose.family<TeamEvent, String>((ref, id) {
  return ref.watch(teamEventRepositoryProvider).find(id);
});
