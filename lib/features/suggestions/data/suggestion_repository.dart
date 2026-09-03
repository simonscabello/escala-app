import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/song_suggestion.dart';

/// Qual metade da lista se está olhando.
///
/// `open` = pendentes que ainda valem (sem data, ou com data que não passou).
/// `closed` = resolvidas, mais as pendentes cujo domingo já foi. A data passar
/// **não** recusa nada: só tira da lista ativa, como a agenda faz com as
/// escalas passadas.
enum SuggestionScope {
  open,
  closed;

  String get query => this == SuggestionScope.open ? 'open' : 'closed';
}

class SuggestionRepository {
  const SuggestionRepository(this._dio);

  final Dio _dio;

  Future<List<SongSuggestion>> list(
    String teamId, {
    SuggestionScope scope = SuggestionScope.open,
  }) async {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/song-suggestions',
        queryParameters: {'scope': scope.query},
      );
      return response.data!
          .map((e) => SongSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<SongSuggestion> create(
    String teamId, {
    required String title,
    required String reason,
    String? songId,
    String? artist,
    String? link,
    DateTime? targetDate,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/song-suggestions',
        data: {
          'title': title,
          'reason': reason,
          if (songId != null) 'songId': songId,
          if (artist != null && artist.isNotEmpty) 'artist': artist,
          if (link != null && link.isNotEmpty) 'link': link,
          if (targetDate != null) 'targetDate': dateKey(targetDate),
        },
      );
      return SongSuggestion.fromJson(response.data!);
    });
  }

  /// O líder acolheu a ideia.
  ///
  /// `songId` só vai quando ele acabou de cadastrar a música a partir da
  /// sugestão. Aceitar **não** liga o `isNew` da música: isso é julgamento
  /// humano e continua sendo marcado à mão no cadastro.
  Future<SongSuggestion> accept(
    String teamId,
    String id, {
    String? songId,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/song-suggestions/$id/accept',
        data: {if (songId != null) 'songId': songId},
      );
      return SongSuggestion.fromJson(response.data!);
    });
  }

  /// "Por enquanto não". O motivo é opcional de propósito.
  Future<SongSuggestion> decline(
    String teamId,
    String id, {
    String? reason,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/song-suggestions/$id/decline',
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
      return SongSuggestion.fromJson(response.data!);
    });
  }

  Future<SongSuggestion> reopen(String teamId, String id) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/song-suggestions/$id/reopen',
      );
      return SongSuggestion.fromJson(response.data!);
    });
  }

  Future<void> remove(String teamId, String id) async {
    return _guard(() async {
      await _dio.delete<void>('/teams/$teamId/song-suggestions/$id');
    });
  }

  /// As pendentes que interessam a quem está montando esta escala.
  Future<EventSuggestions> forEvent(String eventId) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/events/$eventId/song-suggestions',
      );
      return EventSuggestions.fromJson(response.data!);
    });
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// AAAA-MM-DD a partir de uma data de calendário.
///
/// Montado à mão, e não por `toIso8601String()`: aquele devolve o instante, e
/// um `DateTime` local de meia-noite vira o dia anterior em UTC — que é
/// exatamente o erro que a sugestão de domingo não pode cometer.
String dateKey(DateTime date) {
  final mes = date.month.toString().padLeft(2, '0');
  final dia = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mes-$dia';
}

final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  return SuggestionRepository(ref.watch(dioProvider));
});

typedef SuggestionQuery = ({String teamId, SuggestionScope scope});

final suggestionsProvider =
    FutureProvider.autoDispose.family<List<SongSuggestion>, SuggestionQuery>(
  (ref, query) => ref
      .watch(suggestionRepositoryProvider)
      .list(query.teamId, scope: query.scope),
);

/// Quantas sugestões estão de pé — o número do selo na aba Equipe.
///
/// Sem push no projeto, é por este selo que o líder descobre que alguém
/// sugeriu alguma coisa. Reaproveita o mesmo provider da listagem, então abrir
/// a lista logo depois não custa uma segunda ida ao servidor.
final openSuggestionCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, teamId) async {
  final abertas = await ref.watch(
    suggestionsProvider((teamId: teamId, scope: SuggestionScope.open)).future,
  );
  return abertas.length;
});

final eventSuggestionsProvider =
    FutureProvider.autoDispose.family<EventSuggestions, String>(
  (ref, eventId) => ref.watch(suggestionRepositoryProvider).forEvent(eventId),
);
