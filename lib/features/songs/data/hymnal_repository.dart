import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/hymnal_models.dart';

/// Os hinários que o cadastro de música oferece.
///
/// Fora de `/teams/:teamId`: hinário não pertence a equipe — o Cantor Cristão
/// 314 é o mesmo hino em qualquer igreja.
class HymnalRepository {
  const HymnalRepository(this._dio);

  final Dio _dio;

  Future<List<Hymnal>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/hymnals');
      return response.data!
          .map((e) => Hymnal.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final hymnalRepositoryProvider = Provider<HymnalRepository>((ref) {
  return HymnalRepository(ref.watch(dioProvider));
});

/// A lista de hinários, buscada uma vez por sessão.
///
/// Sem `autoDispose`, ao contrário dos providers de música: são três linhas
/// que não mudam entre uma abertura do formulário e a seguinte, e refazer a
/// chamada a cada vez faria o seletor de hinário piscar num campo que a pessoa
/// abriu para digitar um número.
final hymnalsProvider = FutureProvider<List<Hymnal>>((ref) {
  return ref.watch(hymnalRepositoryProvider).list();
});
