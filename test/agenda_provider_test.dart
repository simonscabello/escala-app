import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/storage/read_cache.dart';
import 'package:louvor_app/features/events/data/agenda_provider.dart';
import 'package:louvor_app/features/events/data/event_repository.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reutiliza listas pequenas e amplia apenas quando a página está cheia',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository =
        _Repository(ReadCache(await SharedPreferences.getInstance()));
    var count = 3;
    final container = ProviderContainer(
      overrides: [
        eventsProvider.overrideWith(
          (ref, query) async => CachedValue(
            data: List.generate(count, (i) => Event.fromJson(_json(i))),
            fromCache: false,
          ),
        ),
        eventRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    const query = ('t1', 'upcoming');
    final subscription =
        container.listen(agendaEventsProvider(query), (_, next) {});
    addTearDown(subscription.close);
    expect(
      (await container.read(agendaEventsProvider(query).future)).data,
      hasLength(3),
    );
    expect(repository.calls, 0);
    count = 20;
    container.invalidate(eventsProvider(query));
    expect(
      (await container.read(agendaEventsProvider(query).future)).data,
      hasLength(21),
    );
    expect(repository.limitAsked, 100);
    expect(repository.calls, 1);
  });

  test('consulta ampliada preserva cache da Home e lê o próprio cache offline',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cache = ReadCache(await SharedPreferences.getInstance());
    final dio = Dio();
    addTearDown(dio.close);
    var offline = false;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (offline) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          } else {
            handler.resolve(
              Response<List<dynamic>>(
                requestOptions: options,
                data: List.generate(
                  options.queryParameters['limit'] as int,
                  _json,
                ),
                statusCode: 200,
              ),
            );
          }
        },
      ),
    );
    final repository = EventRepository(dio, cache);
    await repository.list('t1');
    await repository.list('t1', limit: 100);
    expect(cache.readAgenda('t1', 'upcoming')!.data, hasLength(20));
    expect(cache.readAgenda('t1', 'upcoming.100')!.data, hasLength(100));
    offline = true;
    final result = await repository.list('t1', limit: 100);
    expect(result.fromCache, isTrue);
    expect(result.data, hasLength(100));
  });
}

Map<String, dynamic> _json(int i) => {
      'id': 'e$i',
      'teamId': 't1',
      'startsAt': '2026-09-13T12:00:00Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
    };

class _Repository extends EventRepository {
  _Repository(ReadCache cache) : super(Dio(), cache);
  int calls = 0;
  int? limitAsked;

  @override
  Future<CachedValue<List<Event>>> list(
    String teamId, {
    String scope = 'upcoming',
    int limit = 20,
  }) async {
    calls++;
    limitAsked = limit;
    return CachedValue(
      data: List.generate(21, (i) => Event.fromJson(_json(i))),
      fromCache: false,
    );
  }
}
