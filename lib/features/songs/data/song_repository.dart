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
    Set<String> themes = const {},
  }) async {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/teams/$teamId/songs',
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search,
          if (includeArchived) 'includeArchived': true,
          // Separados por vírgula, num parâmetro só: o servidor aceita as duas
          // formas, e esta é a que sobrevive a proxy que reordena parâmetro
          // repetido.
          if (themes.isNotEmpty) 'themes': themes.join(','),
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

  Future<Song> copyFromCatalog(
    String teamId,
    String sourceSongId, {
    bool isNew = false,
    Set<String> themes = const {},
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/teams/$teamId/songs/from-catalog',
        // `isNew` é de quem está adicionando, não da música de origem: que a
        // outra equipe já domine a canção não diz nada sobre esta. Os temas,
        // ao contrário, vêm da origem — estes aqui se somam a eles.
        data: {
          'sourceSongId': sourceSongId,
          'isNew': isNew,
          if (themes.isNotEmpty) 'themes': themes.toList(),
        },
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
    ExternalCandidate candidate, {
    bool isNew = false,
    Set<String> themes = const {},
  }) async {
    return _guard(
      () async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/teams/$teamId/songs/from-external',
          data: {
            'title': candidate.title,
            'artist': candidate.artist,
            'isNew': isNew,
            if (themes.isNotEmpty) 'themes': themes.toList(),
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

/// Filtro da lista. **São dois acervos, não um.**
///
/// O Cantor Cristão entrou inteiro: 581 hinos num repertório de 861 músicas.
/// Numa lista só, dois terços de tudo o que se rola é hino, e procurar um
/// cântico vira garimpo — por isso não existe mais uma aba "Todas". A primeira
/// aba é "Cânticos", e ela **exclui** os hinos.
///
/// "Hinos" percorre por número, que é a ordem do hinário impresso e a única
/// que serve para quem sabe o hino de cor pelo número.
///
/// "Novas" atravessa os dois: um hino pode estar sendo aprendido tanto quanto
/// um cântico.
enum SongFilter { canticos, hinos, novas }

class SongQuery {
  const SongQuery({
    required this.teamId,
    this.search = '',
    this.filter = SongFilter.canticos,
    this.themes = const {},
  });

  final String teamId;
  final String search;
  final SongFilter filter;

  /// Temas marcados no filtro. Vazio = sem filtro de tema.
  ///
  /// **Somam-se aos outros filtros, não os substituem**: "Hinos" + "Ceia" é o
  /// hino que serve à Santa Ceia, que é exatamente a pergunta de quem monta o
  /// culto. Entre si, os temas são um OU — marcar "Natal" e "Páscoa" mostra as
  /// duas listas juntas, porque marcar dois e receber nada seria lido como
  /// defeito.
  final Set<String> themes;

  @override
  bool operator ==(Object other) =>
      other is SongQuery &&
      other.teamId == teamId &&
      other.search == search &&
      other.filter == filter &&
      // `Set` não tem igualdade estrutural em Dart: sem comparar item a item,
      // dois filtros idênticos seriam chaves diferentes do provider e cada
      // reconstrução da tela dispararia uma consulta nova.
      other.themes.length == themes.length &&
      other.themes.containsAll(themes);

  @override
  int get hashCode => Object.hash(
        teamId,
        search,
        filter,
        // Ordenado: `{A, B}` e `{B, A}` são o mesmo filtro e precisam do mesmo
        // código, senão a comparação acima nunca é alcançada.
        Object.hashAll(themes.toList()..sort()),
      );
}

final songsProvider =
    FutureProvider.autoDispose.family<List<Song>, SongQuery>((ref, query) async {
  final songs = await ref
      .watch(songRepositoryProvider)
      .list(query.teamId, search: query.search, themes: query.themes);

  // O filtro é local: a lista inteira já veio, e ir ao servidor de novo só
  // para esconder linhas gastaria uma volta de rede à toa.
  return switch (query.filter) {
    SongFilter.canticos => songs.where((s) => !s.isHymn).toList(),
    SongFilter.novas => songs.where((s) => s.isNew).toList(),
    // Por número, e não por título: é a ordem do hinário impresso, e é assim
    // que se procura um hino que se sabe de cor pelo número.
    SongFilter.hinos => songs.where((s) => s.isHymn).toList()
      ..sort((a, b) => a.hymnNumber!.compareTo(b.hymnNumber!)),
  };
});

final songProvider = FutureProvider.autoDispose
    .family<Song, ({String teamId, String songId})>((ref, args) {
  return ref.watch(songRepositoryProvider).find(args.teamId, args.songId);
});
