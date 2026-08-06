import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/read_cache.dart';
import '../domain/event_models.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider precisa ser overridden');
});

final readCacheProvider = Provider<ReadCache>((ref) {
  return ReadCache(ref.watch(sharedPreferencesProvider));
});

class EventRepository {
  const EventRepository(this._dio, this._cache);

  final Dio _dio;
  final ReadCache _cache;

  Future<CachedValue<List<Event>>> list(
    String teamId, {
    String scope = 'upcoming',
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/events',
        queryParameters: {'scope': scope, 'limit': limit},
      );
      final maps = response.data!
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _cache.saveAgenda(teamId, scope, maps);
      return CachedValue(
        data: maps.map(Event.fromJson).toList(),
        fromCache: false,
      );
    } on DioException catch (e) {
      final cached = _cache.readAgenda(teamId, scope);
      if (cached != null) {
        return CachedValue(
          data: cached.data.map(Event.fromJson).toList(),
          fromCache: true,
          cachedAt: cached.cachedAt,
        );
      }
      throw ApiException.fromDio(e);
    }
  }

  Future<CachedValue<Event>> find(String eventId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/events/$eventId');
      final map = Map<String, dynamic>.from(response.data!);
      await _cache.saveEvent(eventId, map);
      return CachedValue(data: Event.fromJson(map), fromCache: false);
    } on DioException catch (e) {
      final cached = _cache.readEvent(eventId);
      if (cached != null) {
        return CachedValue(
          data: Event.fromJson(cached.data),
          fromCache: true,
          cachedAt: cached.cachedAt,
        );
      }
      throw ApiException.fromDio(e);
    }
  }

  Future<Event> create(
    String teamId, {
    required String title,
    required List<Map<String, String?>> services,
    String? rehearsalAt,
    String? location,
    String? notes,
    String? colorPalette,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/events',
        data: {
          'title': title,
          'services': services,
          if (rehearsalAt != null) 'rehearsalAt': rehearsalAt,
          if (location != null && location.isNotEmpty) 'location': location,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (colorPalette != null && colorPalette.isNotEmpty)
            'colorPalette': colorPalette,
        },
      );
      return Event.fromJson(response.data!);
    });
  }

  Future<Event> update(
    String eventId, {
    String? title,
    List<Map<String, String?>>? services,
    String? rehearsalAt,
    bool removeRehearsalAt = false,
    String? location,
    String? notes,
    String? colorPalette,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/events/$eventId',
        data: {
          if (title != null) 'title': title,
          // Omitir preserva os cultos que já existem: editar só o local não
          // pode apagar os horários.
          if (services != null) 'services': services,
          if (removeRehearsalAt) 'rehearsalAt': null,
          if (rehearsalAt != null) 'rehearsalAt': rehearsalAt,
          if (location != null) 'location': location,
          if (notes != null) 'notes': notes,
          if (colorPalette != null) 'colorPalette': colorPalette,
        },
      );
      return Event.fromJson(response.data!);
    });
  }

  Future<void> remove(String eventId) async {
    return _guard(() async {
      await _dio.delete<void>('/events/$eventId');
    });
  }

  Future<Event> duplicate(String eventId, {required String startsAt}) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/events/$eventId/duplicate',
        data: {'startsAt': startsAt},
      );
      return Event.fromJson(response.data!);
    });
  }

  Future<Event> replaceAssignments(
    String eventId,
    List<Map<String, String?>> assignments,
  ) async {
    return _guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/events/$eventId/assignments',
        data: {
          'assignments': assignments
              .map(
                (item) => {
                  'membershipId': item['membershipId'],
                  'positionId': item['positionId'],
                  if (item['note'] != null && item['note']!.isNotEmpty)
                    'note': item['note'],
                },
              )
              .toList(),
        },
      );
      return Event.fromJson(response.data!);
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

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(
    ref.watch(dioProvider),
    ref.watch(readCacheProvider),
  );
});

typedef EventsQuery = (String teamId, String scope);

final eventsProvider = FutureProvider.autoDispose
    .family<CachedValue<List<Event>>, EventsQuery>((ref, query) {
  final (teamId, scope) = query;
  return ref.watch(eventRepositoryProvider).list(teamId, scope: scope);
});

final eventProvider =
    FutureProvider.autoDispose.family<CachedValue<Event>, String>(
  (ref, eventId) {
    return ref.watch(eventRepositoryProvider).find(eventId);
  },
);
