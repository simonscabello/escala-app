import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/song_models.dart';

class SongRepository {
  const SongRepository(this._dio);

  final Dio _dio;

  Future<List<Song>> list(
    String teamId, {
    String? search,
    bool includeArchived = false,
  }) async {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/songs',
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search,
          if (includeArchived) 'includeArchived': true,
        },
      );
      return response.data!
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Única chamada que traz a letra.
  Future<Song> find(String teamId, String songId) async {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/teams/$teamId/songs/$songId');
      return Song.fromJson(response.data!);
    });
  }

  Future<Song> create(String teamId, Map<String, dynamic> body) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/songs',
        data: body,
      );
      return Song.fromJson(response.data!);
    });
  }

  Future<Song> update(
    String teamId,
    String songId,
    Map<String, dynamic> body,
  ) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/teams/$teamId/songs/$songId',
        data: body,
      );
      return Song.fromJson(response.data!);
    });
  }

  Future<void> remove(String teamId, String songId) async {
    return _guard(() async {
      await _dio.delete<void>('/teams/$teamId/songs/$songId');
    });
  }

  /// Busca a mesma música no repertório das outras equipes.
  Future<List<CatalogCandidate>> catalog(String teamId, String search) async {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/songs/catalog',
        queryParameters: {'search': search},
      );
      return response.data!
          .map((e) => CatalogCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Song> copyFromCatalog(String teamId, String sourceSongId) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/songs/from-catalog',
        data: {'sourceSongId': sourceSongId},
      );
      return Song.fromJson(response.data!);
    });
  }

  Future<List<ExternalCandidate>> searchExternal(
    String teamId,
    String search,
  ) async {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/songs/search-external',
        queryParameters: {'search': search},
      );
      return response.data!
          .map((e) => ExternalCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Cria a partir da escolha da busca externa. A API vai ao CifraClub
  /// resolver cifra, letra, tom e andamento -- por isso demora mais que as
  /// outras chamadas.
  Future<Song> createFromExternal(
    String teamId,
    ExternalCandidate candidate,
  ) async {
    return _guard(
      () async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/teams/$teamId/songs/from-external',
          data: {
            'title': candidate.title,
            'artist': candidate.artist,
            if (candidate.spotifyUrl.isNotEmpty)
              'spotifyUrl': candidate.spotifyUrl,
          },
          options: Options(receiveTimeout: const Duration(seconds: 45)),
        );
        return Song.fromJson(response.data!);
      },
    );
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(ref.watch(dioProvider));
});

/// Filtro da lista. "Faltando dados" é o modo de trabalho: mostra só o que
/// ainda depende de uma decisão da equipe (tom, hino/cântico, andamento).
enum SongFilter { todas, faltandoDados }

class SongQuery {
  const SongQuery({
    required this.teamId,
    this.search = '',
    this.filter = SongFilter.todas,
  });

  final String teamId;
  final String search;
  final SongFilter filter;

  @override
  bool operator ==(Object other) =>
      other is SongQuery &&
      other.teamId == teamId &&
      other.search == search &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(teamId, search, filter);
}

final songsProvider =
    FutureProvider.autoDispose.family<List<Song>, SongQuery>((ref, query) async {
  final songs = await ref
      .watch(songRepositoryProvider)
      .list(query.teamId, search: query.search);

  // O filtro é local: a lista inteira já veio, e ir ao servidor de novo só
  // para esconder linhas gastaria uma volta de rede à toa.
  return query.filter == SongFilter.faltandoDados
      ? songs.where((s) => s.isIncomplete).toList()
      : songs;
});

final songProvider = FutureProvider.autoDispose
    .family<Song, ({String teamId, String songId})>((ref, args) {
  return ref.watch(songRepositoryProvider).find(args.teamId, args.songId);
});
